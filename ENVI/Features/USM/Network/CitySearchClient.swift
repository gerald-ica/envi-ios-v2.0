import Foundation
import MapKit
@preconcurrency import CoreLocation

/// Error type for city search operations.
public enum CitySearchError: Error, Equatable {
    case transport
    case server(status: Int, message: String)
    case decoding
}

/// Oracle city response model (intermediate, not exposed to UI).
private struct OracleCity: Codable {
    let name: String
    let lat: Double
    let lon: Double
    let timezone: String
    let population: Int
}

/// URLSession-backed implementation of CitySearchClientProtocol.
///
/// Implements two methods:
/// 1. `search` — fetches cities from Oracle `/api/v1/cities/search` endpoint
/// 2. `reverseGeocode` — uses MapKit to reverse-geocode coordinates
public final class CitySearchClient: CitySearchClientProtocol {
    public let baseURL: URL
    public let session: URLSession

    /// Initialize with a base URL and URLSession.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for the API (default: prod ENVI API)
    ///   - session: URLSession to use for requests (default: .shared)
    public init(
        baseURL: URL = URL(string: "https://api.envi.app")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Search for cities by query string.
    ///
    /// - Parameter query: Search query (minimum 2 characters). Shorter queries return empty array.
    /// - Returns: Array of matching USMCity objects, sorted by relevance.
    /// - Throws: CitySearchError.server, .transport, or .decoding on failure.
    public func search(_ query: String) async throws -> [USMCity] {
        // Minimum length check — return empty array immediately without network call
        guard query.count >= 2 else {
            return []
        }

        // Build URL
        let searchURL = baseURL.appendingPathComponent("api/v1/cities/search")
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components.url else {
            throw CitySearchError.transport
        }

        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        // Fetch data
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CitySearchError.transport
        }

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CitySearchError.transport
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "Unknown error"
            throw CitySearchError.server(status: httpResponse.statusCode, message: message)
        }

        // Decode JSON
        let decoder = JSONDecoder()
        let oracleCities: [OracleCity]
        do {
            oracleCities = try decoder.decode([OracleCity].self, from: data)
        } catch {
            throw CitySearchError.decoding
        }

        // Map Oracle cities to USMCity
        return oracleCities.map(mapOracleToUSMCity(_:))
    }

    /// Reverse-geocode coordinates to a city.
    ///
    /// Uses MapKit to find a city name and timezone for the given
    /// latitude and longitude. Falls back gracefully to nil on network errors.
    ///
    /// - Parameters:
    ///   - lat: Latitude
    ///   - lon: Longitude
    /// - Returns: USMCity if geocoding succeeds, nil otherwise (network error or no result)
    public func reverseGeocode(lat: Double, lon: Double) async throws -> USMCity? {
        let location = CLLocation(latitude: lat, longitude: lon)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        let mapItems: [MKMapItem]
        do {
            mapItems = try await request.mapItems
        } catch {
            if isRecoverableReverseGeocodeError(error) {
                return nil
            }
            throw error
        }

        guard let mapItem = mapItems.first else {
            return nil
        }

        let addressRepresentations = mapItem.addressRepresentations
        let name = addressRepresentations?.cityName ?? mapItem.name ?? "Unknown"
        let country = addressRepresentations?.regionName ?? ""
        let timezone = mapItem.timeZone?.identifier ?? TimeZone.current.identifier

        return USMCity(
            name: name,
            country: country,
            timezone: timezone,
            lat: lat,
            lon: lon
        )
    }

    // MARK: - Private Helpers

    private func isRecoverableReverseGeocodeError(_ error: Error) -> Bool {
        if let error = error as? CLError, error.code == .network {
            return true
        }

        guard let error = error as? MKError else {
            return false
        }

        switch error.code {
        case .serverFailure, .loadingThrottled, .placemarkNotFound:
            return true
        default:
            return false
        }
    }

    /// Map an Oracle city response to a USMCity by splitting the name field.
    ///
    /// Oracle returns name as "City, State, Country" or "City, Country".
    /// We split on ", " and extract:
    /// - name = first component
    /// - country = last component (or empty if only 1)
    private func mapOracleToUSMCity(_ oracle: OracleCity) -> USMCity {
        let components = oracle.name.components(separatedBy: ", ")

        let name: String
        let country: String

        if components.count >= 3 {
            // "New York, NY, USA" → name = "New York", country = "USA"
            name = components[0]
            country = components.last ?? ""
        } else if components.count == 2 {
            // "London, UK" → name = "London", country = "UK"
            name = components[0]
            country = components[1]
        } else {
            // Single component
            name = oracle.name
            country = ""
        }

        return USMCity(
            name: name,
            country: country,
            timezone: oracle.timezone,
            lat: oracle.lat,
            lon: oracle.lon
        )
    }

    /// Parse error message from JSON response.
    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["detail"] as? String ?? json["message"] as? String else {
            return nil
        }
        return message
    }
}

// OperationRegistry.swift
// ENVI v3 — Operation Registry with Transition, Audio, and Template Slot Integration
// iOS 26+ | Swift 6 Strict Concurrency | Sendable

import Foundation

// MARK: - Operation Category
/// Top-level operation categories
public enum OperationCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case AIcontentawarefillforgaps = "AI content-aware fill for gaps"
    case AItexttospeechnarration = "AI text-to-speech narration"
    case AIselecthighestqualityframe = "AI-select highest quality frame"
    case AIsuggestedstockfootageinsertion = "AI-suggested stock footage insertion"
    case ARproductpreviewonuser = "AR product preview on user"
    case Adaptcontentfornewformat = "Adapt content for new format"
    case Add3Dmodelsto2Dcontent = "Add 3D models to 2D content"
    case Addcaptionssubtitlesalttext = "Add captions/subtitles/alt text"
    case Adjustbodyproportionssubtly = "Adjust body proportions subtly"
    case Amplitudemodulation = "Amplitude modulation"
    case Analyzeaudioforrhythmtempo = "Analyze audio for rhythm/tempo"
    case Analyzebodypositionform = "Analyze body position/form"
    case Applyartisticstyletocontent = "Apply artistic style to content"
    case Applytonematchcolorpalettes = "Apply/tone-match color palettes"
    case Authenticatesignatures = "Authenticate signatures"
    case AutoaddcontextualSFX = "Auto-add contextual SFX"
    case Autoaddcontextualfootage = "Auto-add contextual footage"
    case Autoadjustframingforplatform = "Auto-adjust framing for platform"
    case Autoanimatetypography = "Auto-animate typography"
    case Autoarrangeelements = "Auto-arrange elements"
    case Autocombinatesmultipleimages = "Auto-composite multiple images"
    case Autocreatecalltoaction = "Auto-create call-to-action"
    case Autocreatecoverframe = "Auto-create cover frame"
    case Autocreatecutsbetweenscenes = "Auto-create cuts between scenes"
    case Autocreaterelevanttags = "Auto-create relevant tags"
    case Autocreatetimelapsefromsequence = "Auto-create timelapse from sequence"
    case Autofixflashredeyeinportraits = "Auto-fix flash red-eye in portraits"
    case Autoselectaudioformood = "Auto-select audio for mood"
    case Bandbasedfrequencyshaping = "Band-based frequency shaping"
    case Bestsettingsfordestination = "Best settings for destination"
    case Blurbackgroundlikesmartphoneportrait = "Blur background like smartphone portrait"
    case Brightenandsharpeneyes = "Brighten and sharpen eyes"
    case Changepitchwithoutspeedchange = "Change pitch without speed change"
    case Changespeedwithoutpitchchange = "Change speed without pitch change"
    case Changevoicecharacter = "Change voice character"
    case Checkcontentagainstbrandguidelines = "Check content against brand guidelines"
    case Checkcontentoriginality = "Check content originality"
    case Checkfortechnicalissues = "Check for technical issues"
    case Cleanaudiovisualartifacts = "Clean audio/visual artifacts"
    case Clearatmospherichazeinlandscapes = "Clear atmospheric haze in landscapes"
    case Combineexposuresforhighdynamicrange = "Combine exposures for high dynamic range"
    case Condenselongcontent = "Condense long content"
    case Consistentbrandvoiceacrosscontent = "Consistent brand voice across content"
    case Convertbetweenlanguages = "Convert between languages"
    case Convertspeechtowrittentext = "Convert speech to written text"
    case Correctcolortemperatureautomatically = "Correct color temperature automatically"
    case Create3Ddepthfrom2Dimage = "Create 3D depth from 2D image"
    case Createcontentvariants = "Create content variants"
    case Createengagingheadlines = "Create engaging headlines"
    case Createmotionfromstatic = "Create motion from static"
    case Createmultipleopeninghooks = "Create multiple opening hooks"
    case Createoriginalmusicforcontent = "Create original music for content"
    case Createslowmofromregularfootage = "Create slow-mo from regular footage"
    case Createsphericalcontentfrommultipleangles = "Create spherical content from multiple angles"
    case Crossplatformaspectratio = "Cross-platform aspect ratio"
    case Cutonmusicbeatsautomatically = "Cut on music beats automatically"
    case Determineemotionaltoneoftext = "Determine emotional tone of text"
    case Echoandrepeattiming = "Echo and repeat timing"
    case Eliminateunwantedcolortint = "Eliminate unwanted color tint"
    case Emphasizeboundariesandcontours = "Emphasize boundaries and contours"
    case Enhancedentalbrightness = "Enhance dental brightness"
    case Enhancedetailbeyondnativeresolution = "Enhance detail beyond native resolution"
    case Enhanceedgedefinition = "Enhance edge definition"
    case Ensureconsistentskinacrossshots = "Ensure consistent skin across shots"
    case Eraseunwantedelementsfromscene = "Erase unwanted elements from scene"
    case Eraseunwantedreflections = "Erase unwanted reflections"
    case Estimatenumberofpeople = "Estimate number of people"
    case Estimatesubjectage = "Estimate subject age"
    case Estimatesubjectgender = "Estimate subject gender"
    case Evenoutvolumedifferences = "Even out volume differences"
    case Extractdominantmatchingcolors = "Extract dominant/matching colors"
    case Extractorplacetextinframe = "Extract or place text in frame"
    case Extracttextfromimagevideo = "Extract text from image/video"
    case Findexistingwatermarks = "Find existing watermarks"
    case Findrepeatedcontent = "Find repeated content"
    case Flaginappropriatecontent = "Flag inappropriate content"
    case Followmovingsubjectsacrossframes = "Follow moving subjects across frames"
    case Frequencycontentvisualization = "Frequency content visualization"
    case Gaussianorlensblurbehindsubject = "Gaussian or lens blur behind subject"
    case Generateenvironmentalaudiobed = "Generate environmental audio bed"
    case Generateintermediateframesforsmoothmotion = "Generate intermediate frames for smooth motion"
    case GeneratemultipleCTAs = "Generate multiple CTAs"
    case Generatemultiplethumbnailoptions = "Generate multiple thumbnail options"
    case Generatemultipletitleoptions = "Generate multiple title options"
    case Generateseamlesstextures = "Generate seamless textures"
    case Generativefillforaspectratioconversion = "Generative fill for aspect ratio conversion"
    case IdentifyBPM = "Identify BPM"
    case Identifybrandmarksincontent = "Identify brand marks in content"
    case Identifycarstrucksbikes = "Identify cars/trucks/bikes"
    case Identifyclappingcheering = "Identify clapping/cheering"
    case Identifydeadair = "Identify dead air"
    case Identifydocumentboundaries = "Identify document boundaries"
    case Identifyemotionaltone = "Identify emotional tone"
    case Identifyfacialexpressions = "Identify facial expressions"
    case Identifyfundamentalfrequency = "Identify fundamental frequency"
    case Identifygraphtypes = "Identify graph types"
    case Identifyhandbodygestures = "Identify hand/body gestures"
    case Identifyharmonicprogression = "Identify harmonic progression"
    case Identifyhumanactivities = "Identify human activities"
    case Identifyimportantterms = "Identify important terms"
    case Identifylaughmoments = "Identify laugh moments"
    case Identifymainmelodicline = "Identify main melodic line"
    case Identifymathematicalexpressions = "Identify mathematical expressions"
    case Identifymusicalkey = "Identify musical key"
    case Identifymusicalstyle = "Identify musical style"
    case Identifynoteeventstarts = "Identify note/event starts"
    case Identifypeopleplacesthingsintext = "Identify people/places/things in text"
    case Identifypersonfalling = "Identify person falling"
    case Identifyprimarysubjectinframe = "Identify primary subject in frame"
    case Identifyproductsitems = "Identify products/items"
    case Identifyscannablecodes = "Identify scannable codes"
    case Identifyshotboundaries = "Identify shot boundaries"
    case Identifyspecificchoreography = "Identify specific choreography"
    case Identifyspecificindividuals = "Identify specific individuals"
    case Identifyspecificoccurrences = "Identify specific occurrences"
    case Identifyspokenwrittenlanguage = "Identify spoken/written language"
    case Identifysubjectmatter = "Identify subject matter"
    case Identifytabulardata = "Identify tabular data"
    case Identifytalkingvsmusic = "Identify talking vs music"
    case Identifyunusualevents = "Identify unusual events"
    case Identifyunwantedcontent = "Identify unwanted content"
    case Identifywhoisspeakingwhen = "Identify who is speaking when"
    case Improveresolutionquality = "Improve resolution/quality"
    case Improvesearchvisibility = "Improve search visibility"
    case Improvespeechclarityandpresence = "Improve speech clarity and presence"
    case Increasetonalseparation = "Increase tonal separation"
    case Instantlocalization = "Instant localization"
    case Interprethandsigns = "Interpret hand signs"
    case Isolateinstrumentsfrommix = "Isolate instruments from mix"
    case Isolatelowfrequencies = "Isolate low frequencies"
    case Isolatepercussionfrommix = "Isolate percussion from mix"
    case Isolatesubjectfrombackground = "Isolate subject from background"
    case Isolatevocalsfromtrack = "Isolate vocals from track"
    case Keepsubjectscenteredacrossformats = "Keep subjects centered across formats"
    case Locateandtrackfacialfeatures = "Locate and track facial features"
    case Manualpitchadjustment = "Manual pitch adjustment"
    case MapHDRtodisplayablerange = "Map HDR to displayable range"
    case Mergemultiplefocalplanesforfullsharpness = "Merge multiple focal planes for full sharpness"
    case Mergemultipleimagesintowidepanorama = "Merge multiple images into wide panorama"
    case Phaseshiftsweeping = "Phase-shift sweeping"
    case Pickbestshotfromburstsequence = "Pick best shot from burst sequence"
    case Pitchcorrectiontoscale = "Pitch correction to scale"
    case Pitchmodulation = "Pitch modulation"
    case Positionaudioin3Dspace = "Position audio in 3D space"
    case Positionvirtualobjectsinscene = "Position virtual objects in scene"
    case Prepublishperformanceforecasting = "Pre-publish performance forecasting"
    case Precisefrequencyadjustment = "Precise frequency adjustment"
    case Preventdigitalclipping = "Prevent digital clipping"
    case Previewdifferenthaircolors = "Preview different hair colors"
    case Pullsubjecttoseparatelayer = "Pull subject to separate layer"
    case Readhandwrittentext = "Read handwritten text"
    case Readsheetmusic = "Read sheet music"
    case Readvehicleregistration = "Read vehicle registration"
    case Realspaceacousticsimulation = "Real-space acoustic simulation"
    case Recovershadowsandhighlights = "Recover shadows and highlights"
    case Redistributetonalvalues = "Redistribute tonal values"
    case Reducefilesizeforplatform = "Reduce file size for platform"
    case Reducegrainnoiseinlowlight = "Reduce grain/noise in low-light"
    case Reduceoreliminateharshshadows = "Reduce or eliminate harsh shadows"
    case Reframefordifferentplatforms = "Reframe for different platforms"
    case Removevocalsforkaraoke = "Remove vocals for karaoke"
    case Separatevoicefrombackgroundnoise = "Separate voice from background noise"
    case Sharpenmotionoroutoffocusblur = "Sharpen motion or out-of-focus blur"
    case Smoothshakyfootage = "Smooth shaky footage"
    case Speechtotextwithstyling = "Speech-to-text with styling"
    case Splitaudiointocomponents = "Split audio into components"
    case Stabilizedspedupmovingfootage = "Stabilized sped-up moving footage"
    case Standardizeperceivedvolume = "Standardize perceived volume"
    case Styleconsistentcolortreatment = "Style-consistent color treatment"
    case Subtlecomplexionenhancement = "Subtle complexion enhancement"
    case Superresolutionenhancement = "Super-resolution enhancement"
    case Swapskywithdifferentweathertime = "Swap sky with different weather/time"
    case Sweepingcombfilter = "Sweeping comb filter"
    case Syntheticspacegeneration = "Synthetic space generation"
    case Tailorforspecificplatform = "Tailor for specific platform"
    case Targetedfrequencycompression = "Targeted frequency compression"
    case Thickenwithdetunedcopies = "Thicken with detuned copies"
    case Trackgazedirection = "Track gaze direction"
    case Trendingtextanimationstypewriterbounceglow = "Trending text animations (typewriter, bounce, glow)"
    case Variableplaybackspeed = "Variable playback speed"
    case Writeaccessibilitydescriptions = "Write accessibility descriptions"
    case Writedescriptivetext = "Write descriptive text"
    case Writedetailedcontentdescription = "Write detailed content description"
}

// MARK: - Algorithmic Operation
/// All 183 algorithmic operations available in ENVI
public enum AlgorithmicOperation: String, Codable, Sendable, CaseIterable, Hashable {
    case SubjectDetection = "Subject Detection"
    case FaceDetection = "Face Detection"
    case BeatDetection = "Beat Detection"
    case SceneDetection = "Scene Detection"
    case TextDetection = "Text Detection"
    case ObjectDetection = "Object Detection"
    case PoseDetection = "Pose Detection"
    case ColorAnalysis = "Color Analysis"
    case SmartCropReframe = "Smart Crop/Reframe"
    case BackgroundRemoval = "Background Removal"
    case SpeedRamping = "Speed Ramping"
    case TransitionGeneration = "Transition Generation"
    case ColorGrading = "Color Grading"
    case TextAnimation = "Text Animation"
    case Stabilization = "Stabilization"
    case NoiseReduction = "Noise Reduction"
    case UpscalingEnhancement = "Upscaling/Enhancement"
    case FormatConversion = "Format Conversion"
    case AutoCaptionGeneration = "Auto-Caption Generation"
    case MusicSFXMatching = "Music/SFX Matching"
    case ThumbnailGeneration = "Thumbnail Generation"
    case TemplateLayoutGeneration = "Template Layout Generation"
    case FilterPresetApplication = "Filter/Preset Application"
    case CollageMosaicCreation = "Collage/Mosaic Creation"
    case AnimationGeneration = "Animation Generation"
    case VoiceoverGeneration = "Voiceover Generation"
    case BRollInsertion = "B-Roll Insertion"
    case EndCardCTAGeneration = "End Card/CTA Generation"
    case AIBackgroundExtension = "AI Background Extension"
    case AutoReframewithFaceTracking = "Auto-Reframe with Face Tracking"
    case DynamicCaptionStyling = "Dynamic Caption Styling"
    case SmartBRollSuggestion = "Smart B-Roll Suggestion"
    case VoiceCloneNarration = "Voice Clone Narration"
    case MultiLanguageAutoDub = "Multi-Language Auto-Dub"
    case EngagementPredictionScoring = "Engagement Prediction Scoring"
    case GenerativeFill = "Generative Fill"
    case AIUpscaling = "AI Upscaling"
    case MotionTracking = "Motion Tracking"
    case ObjectRemoval = "Object Removal"
    case SkyReplacement = "Sky Replacement"
    case DepthMapGeneration = "Depth Map Generation"
    case PortraitModeSimulation = "Portrait Mode Simulation"
    case StyleTransfer = "Style Transfer"
    case TextureSynthesis = "Texture Synthesis"
    case SuperResolution = "Super Resolution"
    case FrameInterpolation = "Frame Interpolation"
    case SlowMotionGeneration = "Slow Motion Generation"
    case HyperlapseGeneration = "Hyperlapse Generation"
    case TimelapseAuto = "Timelapse Auto"
    case PanoramaStitching = "Panorama Stitching"
    case ThreeSixZeroStitching = "360 Stitching"
    case HDRMerge = "HDR Merge"
    case FocusStacking = "Focus Stacking"
    case BurstPhotoSelection = "Burst Photo Selection"
    case BestShotSelection = "Best Shot Selection"
    case RedEyeRemoval = "Red Eye Removal"
    case TeethWhitening = "Teeth Whitening"
    case SkinSmoothing = "Skin Smoothing"
    case BodyReshape = "Body Reshape"
    case BackgroundBlur = "Background Blur"
    case ForegroundExtraction = "Foreground Extraction"
    case ShadowRemoval = "Shadow Removal"
    case ReflectionRemoval = "Reflection Removal"
    case HazeRemoval = "Haze Removal"
    case Deblurring = "Deblurring"
    case Denoising = "Denoising"
    case Sharpening = "Sharpening"
    case EdgeEnhancement = "Edge Enhancement"
    case ContrastEnhancement = "Contrast Enhancement"
    case DynamicRangeExpansion = "Dynamic Range Expansion"
    case ToneMapping = "Tone Mapping"
    case HistogramEqualization = "Histogram Equalization"
    case WhiteBalanceAuto = "White Balance Auto"
    case ColorCastRemoval = "Color Cast Removal"
    case SkinToneMatching = "Skin Tone Matching"
    case EyeColorEnhancement = "Eye Color Enhancement"
    case HairColorSimulation = "Hair Color Simulation"
    case VirtualTryOn = "Virtual Try-On"
    case AROverlayPlacement = "AR Overlay Placement"
    case ThreeDAssetInsertion = "3D Asset Insertion"
    case SpatialAudioMixing = "Spatial Audio Mixing"
    case BeatMatchedCutGeneration = "Beat-Matched Cut Generation"
    case AIMusicGeneration = "AI Music Generation"
    case SoundEffectGeneration = "Sound Effect Generation"
    case AmbientSoundscape = "Ambient Soundscape"
    case VoiceIsolation = "Voice Isolation"
    case DialogueEnhancement = "Dialogue Enhancement"
    case LoudnessNormalization = "Loudness Normalization"
    case TruePeakLimiting = "True Peak Limiting"
    case DynamicRangeCompression = "Dynamic Range Compression"
    case MultibandCompression = "Multiband Compression"
    case ParametricEQ = "Parametric EQ"
    case GraphicEQ = "Graphic EQ"
    case ConvolutionReverb = "Convolution Reverb"
    case AlgorithmicReverb = "Algorithmic Reverb"
    case DelayEffect = "Delay Effect"
    case ChorusEffect = "Chorus Effect"
    case FlangerEffect = "Flanger Effect"
    case PhaserEffect = "Phaser Effect"
    case TremoloEffect = "Tremolo Effect"
    case VibratoEffect = "Vibrato Effect"
    case AutoTune = "Auto-Tune"
    case PitchCorrection = "Pitch Correction"
    case TimeStretching = "Time-Stretching"
    case PitchShifting = "Pitch-Shifting"
    case FormantShifting = "Formant Shifting"
    case StemSeparation = "Stem Separation"
    case SourceSeparation = "Source Separation"
    case InstrumentalExtraction = "Instrumental Extraction"
    case AcapellaExtraction = "Acapella Extraction"
    case Transcription = "Transcription"
    case ChordDetection = "Chord Detection"
    case KeyDetection = "Key Detection"
    case TempoDetection = "Tempo Detection"
    case GenreClassification = "Genre Classification"
    case MoodClassification = "Mood Classification"
    case SpectralAnalysis = "Spectral Analysis"
    case OnsetDetection = "Onset Detection"
    case PitchDetection = "Pitch Detection"
    case MelodyExtraction = "Melody Extraction"
    case DrumExtraction = "Drum Extraction"
    case BassExtraction = "Bass Extraction"
    case LaughterDetection = "Laughter Detection"
    case ApplauseDetection = "Applause Detection"
    case SilenceDetection = "Silence Detection"
    case SpeechDetection = "Speech Detection"
    case SpeakerDiarization = "Speaker Diarization"
    case PlagiarismDetection = "Plagiarism Detection"
    case DuplicateDetection = "Duplicate Detection"
    case ContentModeration = "Content Moderation"
    case BrandSafety = "Brand Safety"
    case LogoDetection = "Logo Detection"
    case WatermarkDetection = "Watermark Detection"
    case BarcodeQRDetection = "Barcode/QR Detection"
    case FaceRecognition = "Face Recognition"
    case AgeEstimation = "Age Estimation"
    case GenderClassification = "Gender Classification"
    case EmotionRecognition = "Emotion Recognition"
    case AttentionDetection = "Attention Detection"
    case CrowdCounting = "Crowd Counting"
    case VehicleDetection = "Vehicle Detection"
    case LicensePlateRecognition = "License Plate Recognition"
    case DocumentDetection = "Document Detection"
    case OCR = "OCR"
    case HandwritingRecognition = "Handwriting Recognition"
    case SignatureVerification = "Signature Verification"
    case TableDetection = "Table Detection"
    case ChartDetection = "Chart Detection"
    case FormulaDetection = "Formula Detection"
    case MusicNotationDetection = "Music Notation Detection"
    case DanceMoveRecognition = "Dance Move Recognition"
    case ActionRecognition = "Action Recognition"
    case GestureRecognition = "Gesture Recognition"
    case SignLanguageRecognition = "Sign Language Recognition"
    case FallDetection = "Fall Detection"
    case AnomalyDetection = "Anomaly Detection"
    case EventDetection = "Event Detection"
    case SpamDetection = "Spam Detection"
    case SentimentAnalysis = "Sentiment Analysis"
    case TopicModeling = "Topic Modeling"
    case NamedEntityRecognition = "Named Entity Recognition"
    case LanguageDetection = "Language Detection"
    case Translation = "Translation"
    case Summarization = "Summarization"
    case KeywordExtraction = "Keyword Extraction"
    case HashtagGeneration = "Hashtag Generation"
    case CaptionGeneration = "Caption Generation"
    case TitleGeneration = "Title Generation"
    case DescriptionGeneration = "Description Generation"
    case AltTextGeneration = "Alt Text Generation"
    case SEOOptimization = "SEO Optimization"
    case ABTestGeneration = "A/B Test Generation"
    case ThumbnailAB = "Thumbnail A/B"
    case TitleAB = "Title A/B"
    case HookVariation = "Hook Variation"
    case CalltoActionVariation = "Call-to-Action Variation"
    case ContentRepurposing = "Content Repurposing"
    case AspectRatioAdaptation = "Aspect Ratio Adaptation"
    case PlatformOptimization = "Platform Optimization"
    case AccessibilityOptimization = "Accessibility Optimization"
    case CompressionOptimization = "Compression Optimization"
    case QualityAssurance = "Quality Assurance"
    case ExportOptimization = "Export Optimization"

    /// The category this operation belongs to
    public var category: OperationCategory {
        switch self {
        case .SubjectDetection: return .Identifyprimarysubjectinframe
        case .FaceDetection: return .Locateandtrackfacialfeatures
        case .BeatDetection: return .Analyzeaudioforrhythmtempo
        case .SceneDetection: return .Identifyshotboundaries
        case .TextDetection: return .Extractorplacetextinframe
        case .ObjectDetection: return .Identifyproductsitems
        case .PoseDetection: return .Analyzebodypositionform
        case .ColorAnalysis: return .Extractdominantmatchingcolors
        case .SmartCropReframe: return .Autoadjustframingforplatform
        case .BackgroundRemoval: return .Isolatesubjectfrombackground
        case .SpeedRamping: return .Variableplaybackspeed
        case .TransitionGeneration: return .Autocreatecutsbetweenscenes
        case .ColorGrading: return .Applytonematchcolorpalettes
        case .TextAnimation: return .Autoanimatetypography
        case .Stabilization: return .Smoothshakyfootage
        case .NoiseReduction: return .Cleanaudiovisualartifacts
        case .UpscalingEnhancement: return .Improveresolutionquality
        case .FormatConversion: return .Crossplatformaspectratio
        case .AutoCaptionGeneration: return .Speechtotextwithstyling
        case .MusicSFXMatching: return .Autoselectaudioformood
        case .ThumbnailGeneration: return .Autocreatecoverframe
        case .TemplateLayoutGeneration: return .Autoarrangeelements
        case .FilterPresetApplication: return .Styleconsistentcolortreatment
        case .CollageMosaicCreation: return .Autocombinatesmultipleimages
        case .AnimationGeneration: return .Createmotionfromstatic
        case .VoiceoverGeneration: return .AItexttospeechnarration
        case .BRollInsertion: return .Autoaddcontextualfootage
        case .EndCardCTAGeneration: return .Autocreatecalltoaction
        case .AIBackgroundExtension: return .Generativefillforaspectratioconversion
        case .AutoReframewithFaceTracking: return .Keepsubjectscenteredacrossformats
        case .DynamicCaptionStyling: return .Trendingtextanimationstypewriterbounceglow
        case .SmartBRollSuggestion: return .AIsuggestedstockfootageinsertion
        case .VoiceCloneNarration: return .Consistentbrandvoiceacrosscontent
        case .MultiLanguageAutoDub: return .Instantlocalization
        case .EngagementPredictionScoring: return .Prepublishperformanceforecasting
        case .GenerativeFill: return .AIcontentawarefillforgaps
        case .AIUpscaling: return .Superresolutionenhancement
        case .MotionTracking: return .Followmovingsubjectsacrossframes
        case .ObjectRemoval: return .Eraseunwantedelementsfromscene
        case .SkyReplacement: return .Swapskywithdifferentweathertime
        case .DepthMapGeneration: return .Create3Ddepthfrom2Dimage
        case .PortraitModeSimulation: return .Blurbackgroundlikesmartphoneportrait
        case .StyleTransfer: return .Applyartisticstyletocontent
        case .TextureSynthesis: return .Generateseamlesstextures
        case .SuperResolution: return .Enhancedetailbeyondnativeresolution
        case .FrameInterpolation: return .Generateintermediateframesforsmoothmotion
        case .SlowMotionGeneration: return .Createslowmofromregularfootage
        case .HyperlapseGeneration: return .Stabilizedspedupmovingfootage
        case .TimelapseAuto: return .Autocreatetimelapsefromsequence
        case .PanoramaStitching: return .Mergemultipleimagesintowidepanorama
        case .ThreeSixZeroStitching: return .Createsphericalcontentfrommultipleangles
        case .HDRMerge: return .Combineexposuresforhighdynamicrange
        case .FocusStacking: return .Mergemultiplefocalplanesforfullsharpness
        case .BurstPhotoSelection: return .Pickbestshotfromburstsequence
        case .BestShotSelection: return .AIselecthighestqualityframe
        case .RedEyeRemoval: return .Autofixflashredeyeinportraits
        case .TeethWhitening: return .Enhancedentalbrightness
        case .SkinSmoothing: return .Subtlecomplexionenhancement
        case .BodyReshape: return .Adjustbodyproportionssubtly
        case .BackgroundBlur: return .Gaussianorlensblurbehindsubject
        case .ForegroundExtraction: return .Pullsubjecttoseparatelayer
        case .ShadowRemoval: return .Reduceoreliminateharshshadows
        case .ReflectionRemoval: return .Eraseunwantedreflections
        case .HazeRemoval: return .Clearatmospherichazeinlandscapes
        case .Deblurring: return .Sharpenmotionoroutoffocusblur
        case .Denoising: return .Reducegrainnoiseinlowlight
        case .Sharpening: return .Enhanceedgedefinition
        case .EdgeEnhancement: return .Emphasizeboundariesandcontours
        case .ContrastEnhancement: return .Increasetonalseparation
        case .DynamicRangeExpansion: return .Recovershadowsandhighlights
        case .ToneMapping: return .MapHDRtodisplayablerange
        case .HistogramEqualization: return .Redistributetonalvalues
        case .WhiteBalanceAuto: return .Correctcolortemperatureautomatically
        case .ColorCastRemoval: return .Eliminateunwantedcolortint
        case .SkinToneMatching: return .Ensureconsistentskinacrossshots
        case .EyeColorEnhancement: return .Brightenandsharpeneyes
        case .HairColorSimulation: return .Previewdifferenthaircolors
        case .VirtualTryOn: return .ARproductpreviewonuser
        case .AROverlayPlacement: return .Positionvirtualobjectsinscene
        case .ThreeDAssetInsertion: return .Add3Dmodelsto2Dcontent
        case .SpatialAudioMixing: return .Positionaudioin3Dspace
        case .BeatMatchedCutGeneration: return .Cutonmusicbeatsautomatically
        case .AIMusicGeneration: return .Createoriginalmusicforcontent
        case .SoundEffectGeneration: return .AutoaddcontextualSFX
        case .AmbientSoundscape: return .Generateenvironmentalaudiobed
        case .VoiceIsolation: return .Separatevoicefrombackgroundnoise
        case .DialogueEnhancement: return .Improvespeechclarityandpresence
        case .LoudnessNormalization: return .Standardizeperceivedvolume
        case .TruePeakLimiting: return .Preventdigitalclipping
        case .DynamicRangeCompression: return .Evenoutvolumedifferences
        case .MultibandCompression: return .Targetedfrequencycompression
        case .ParametricEQ: return .Precisefrequencyadjustment
        case .GraphicEQ: return .Bandbasedfrequencyshaping
        case .ConvolutionReverb: return .Realspaceacousticsimulation
        case .AlgorithmicReverb: return .Syntheticspacegeneration
        case .DelayEffect: return .Echoandrepeattiming
        case .ChorusEffect: return .Thickenwithdetunedcopies
        case .FlangerEffect: return .Sweepingcombfilter
        case .PhaserEffect: return .Phaseshiftsweeping
        case .TremoloEffect: return .Amplitudemodulation
        case .VibratoEffect: return .Pitchmodulation
        case .AutoTune: return .Pitchcorrectiontoscale
        case .PitchCorrection: return .Manualpitchadjustment
        case .TimeStretching: return .Changespeedwithoutpitchchange
        case .PitchShifting: return .Changepitchwithoutspeedchange
        case .FormantShifting: return .Changevoicecharacter
        case .StemSeparation: return .Isolateinstrumentsfrommix
        case .SourceSeparation: return .Splitaudiointocomponents
        case .InstrumentalExtraction: return .Removevocalsforkaraoke
        case .AcapellaExtraction: return .Isolatevocalsfromtrack
        case .Transcription: return .Convertspeechtowrittentext
        case .ChordDetection: return .Identifyharmonicprogression
        case .KeyDetection: return .Identifymusicalkey
        case .TempoDetection: return .IdentifyBPM
        case .GenreClassification: return .Identifymusicalstyle
        case .MoodClassification: return .Identifyemotionaltone
        case .SpectralAnalysis: return .Frequencycontentvisualization
        case .OnsetDetection: return .Identifynoteeventstarts
        case .PitchDetection: return .Identifyfundamentalfrequency
        case .MelodyExtraction: return .Identifymainmelodicline
        case .DrumExtraction: return .Isolatepercussionfrommix
        case .BassExtraction: return .Isolatelowfrequencies
        case .LaughterDetection: return .Identifylaughmoments
        case .ApplauseDetection: return .Identifyclappingcheering
        case .SilenceDetection: return .Identifydeadair
        case .SpeechDetection: return .Identifytalkingvsmusic
        case .SpeakerDiarization: return .Identifywhoisspeakingwhen
        case .PlagiarismDetection: return .Checkcontentoriginality
        case .DuplicateDetection: return .Findrepeatedcontent
        case .ContentModeration: return .Flaginappropriatecontent
        case .BrandSafety: return .Checkcontentagainstbrandguidelines
        case .LogoDetection: return .Identifybrandmarksincontent
        case .WatermarkDetection: return .Findexistingwatermarks
        case .BarcodeQRDetection: return .Identifyscannablecodes
        case .FaceRecognition: return .Identifyspecificindividuals
        case .AgeEstimation: return .Estimatesubjectage
        case .GenderClassification: return .Estimatesubjectgender
        case .EmotionRecognition: return .Identifyfacialexpressions
        case .AttentionDetection: return .Trackgazedirection
        case .CrowdCounting: return .Estimatenumberofpeople
        case .VehicleDetection: return .Identifycarstrucksbikes
        case .LicensePlateRecognition: return .Readvehicleregistration
        case .DocumentDetection: return .Identifydocumentboundaries
        case .OCR: return .Extracttextfromimagevideo
        case .HandwritingRecognition: return .Readhandwrittentext
        case .SignatureVerification: return .Authenticatesignatures
        case .TableDetection: return .Identifytabulardata
        case .ChartDetection: return .Identifygraphtypes
        case .FormulaDetection: return .Identifymathematicalexpressions
        case .MusicNotationDetection: return .Readsheetmusic
        case .DanceMoveRecognition: return .Identifyspecificchoreography
        case .ActionRecognition: return .Identifyhumanactivities
        case .GestureRecognition: return .Identifyhandbodygestures
        case .SignLanguageRecognition: return .Interprethandsigns
        case .FallDetection: return .Identifypersonfalling
        case .AnomalyDetection: return .Identifyunusualevents
        case .EventDetection: return .Identifyspecificoccurrences
        case .SpamDetection: return .Identifyunwantedcontent
        case .SentimentAnalysis: return .Determineemotionaltoneoftext
        case .TopicModeling: return .Identifysubjectmatter
        case .NamedEntityRecognition: return .Identifypeopleplacesthingsintext
        case .LanguageDetection: return .Identifyspokenwrittenlanguage
        case .Translation: return .Convertbetweenlanguages
        case .Summarization: return .Condenselongcontent
        case .KeywordExtraction: return .Identifyimportantterms
        case .HashtagGeneration: return .Autocreaterelevanttags
        case .CaptionGeneration: return .Writedescriptivetext
        case .TitleGeneration: return .Createengagingheadlines
        case .DescriptionGeneration: return .Writedetailedcontentdescription
        case .AltTextGeneration: return .Writeaccessibilitydescriptions
        case .SEOOptimization: return .Improvesearchvisibility
        case .ABTestGeneration: return .Createcontentvariants
        case .ThumbnailAB: return .Generatemultiplethumbnailoptions
        case .TitleAB: return .Generatemultipletitleoptions
        case .HookVariation: return .Createmultipleopeninghooks
        case .CalltoActionVariation: return .GeneratemultipleCTAs
        case .ContentRepurposing: return .Adaptcontentfornewformat
        case .AspectRatioAdaptation: return .Reframefordifferentplatforms
        case .PlatformOptimization: return .Tailorforspecificplatform
        case .AccessibilityOptimization: return .Addcaptionssubtitlesalttext
        case .CompressionOptimization: return .Reducefilesizeforplatform
        case .QualityAssurance: return .Checkfortechnicalissues
        case .ExportOptimization: return .Bestsettingsfordestination
        }
    }

    /// Whether this operation requires GPU acceleration
    public var requiresGPU: Bool {
        switch self {
        case .StyleTransfer, .SuperResolution, .ColorGrading, .SmartCropReframe,
             .BodyReshape, .ObjectRemoval, .SkyReplacement, .BeatMatchedCutGeneration,
             .MotionTracking, .DepthMapGeneration, .ForegroundExtraction, .AIBackgroundExtension:
            return true
        default:
            return false
        }
    }

    /// Whether this operation uses Vision framework
    public var usesVision: Bool {
        switch self {
        case .SubjectDetection, .FaceDetection, .TextDetection, .BarcodeQRDetection,
             .SceneDetection, .ObjectDetection, .ColorAnalysis,
             .EdgeEnhancement, .DocumentDetection,
             .AnimalRecognition, .HandPoseDetection, .BodyPoseDetection:
            return true
        default:
            return false
        }
    }

    /// Whether this operation uses CoreML
    public var usesCoreML: Bool {
        switch self {
        case .EngagementPredictionScoring, .StyleTransfer, .MoodClassification,
             .VibeAnalysis, .EmbeddingGeneration, .ContentModeration,
             .DuplicateDetection, .QualityAssurance, .BlurDetection, .NoiseEstimation:
            return true
        default:
            return false
        }
    }

    /// Whether this operation is a transition-related operation
    public var isTransitionOperation: Bool {
        switch self {
        case .TransitionGeneration, .SpeedRamping, .FrameInterpolation,
             .SlowMotionGeneration, .HyperlapseGeneration, .TimelapseAuto,
             .BeatMatchedCutGeneration, .AnimationGeneration:
            return true
        default:
            return false
        }
    }

    /// Whether this operation is audio-related
    public var isAudioOperation: Bool {
        switch self {
        case .BeatDetection, .MusicSFXMatching, .SpatialAudioMixing,
             .AIMusicGeneration, .SoundEffectGeneration, .AmbientSoundscape,
             .VoiceIsolation, .DialogueEnhancement, .LoudnessNormalization,
             .TruePeakLimiting, .DynamicRangeCompression, .MultibandCompression,
             .ParametricEQ, .GraphicEQ, .ConvolutionReverb, .AlgorithmicReverb,
             .DelayEffect, .ChorusEffect, .FlangerEffect, .PhaserEffect,
             .TremoloEffect, .VibratoEffect, .AutoTune, .PitchCorrection,
             .TimeStretching, .PitchShifting, .FormantShifting, .StemSeparation,
             .SourceSeparation, .InstrumentalExtraction, .AcapellaExtraction,
             .Transcription, .ChordDetection, .KeyDetection, .TempoDetection,
             .GenreClassification, .MoodClassification, .SpectralAnalysis,
             .OnsetDetection, .PitchDetection, .MelodyExtraction, .DrumExtraction,
             .BassExtraction, .LaughterDetection, .ApplauseDetection,
             .SilenceDetection, .SpeechDetection, .SpeakerDiarization,
             .VoiceoverGeneration, .VoiceCloneNarration, .MultiLanguageAutoDub:
            return true
        default:
            return false
        }
    }
}

// MARK: - Transition Type
/// Types of transitions available for video editing — used by templates and the execution engine
@available(iOS 26, *)
public enum TransitionType: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case none = "None"
    case crossDissolve = "Cross Dissolve"
    case crossBlur = "Cross Blur"
    case fadeToBlack = "Fade to Black"
    case fadeToWhite = "Fade to White"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case pushLeft = "Push Left"
    case pushRight = "Push Right"
    case pushUp = "Push Up"
    case pushDown = "Push Down"
    case wipeLeft = "Wipe Left"
    case wipeRight = "Wipe Right"
    case wipeUp = "Wipe Up"
    case wipeDown = "Wipe Down"
    case zoomIn = "Zoom In"
    case zoomOut = "Zoom Out"
    case spinClockwise = "Spin Clockwise"
    case spinCounterClockwise = "Spin Counter-Clockwise"
    case flash = "Flash"
    case glitch = "Glitch"
    case morphCut = "Morph Cut"
    case lightLeak = "Light Leak"
    case filmBurn = "Film Burn"
    case swipeDiagonal = "Swipe Diagonal"
    case circleReveal = "Circle Reveal"
    case irisIn = "Iris In"
    case irisOut = "Iris Out"
    case ripple = "Ripple"
    case wave = "Wave"
    case pixelate = "Pixelate"
    case blurDissolve = "Blur Dissolve"
    case directionalWarp = "Directional Warp"
    case cubeSpin = "Cube Spin"
    case pageCurl = "Page Curl"
    case shutter = "Shutter"
    case dreamy = "Dreamy"
    case bounce = "Bounce"
    case elastic = "Elastic"
    case snapZoom = "Snap Zoom"
    case whipPan = "Whip Pan"
    case speedRamp = "Speed Ramp"
    case beatSync = "Beat Sync"

    public var id: String { rawValue }

    /// Default duration for this transition type
    public var defaultDuration: TimeInterval {
        switch self {
        case .none:
            return 0.0
        case .morphCut, .flash, .glitch:
            return 0.1
        case .crossDissolve, .fadeToBlack, .fadeToWhite, .crossBlur, .blurDissolve:
            return 0.5
        case .slideLeft, .slideRight, .slideUp, .slideDown,
             .pushLeft, .pushRight, .pushUp, .pushDown,
             .wipeLeft, .wipeRight, .wipeUp, .wipeDown,
             .zoomIn, .zoomOut, .snapZoom, .whipPan, .speedRamp, .beatSync:
            return 0.4
        case .spinClockwise, .spinCounterClockwise, .circleReveal,
             .irisIn, .irisOut, .ripple, .wave, .pixelate,
             .directionalWarp, .cubeSpin, .pageCurl, .shutter,
             .dreamy, .bounce, .elastic, .lightLeak, .filmBurn, .swipeDiagonal:
            return 0.6
        }
    }

    /// Whether this transition requires beat-sync analysis
    public var requiresBeatSync: Bool {
        switch self {
        case .beatSync, .speedRamp, .whipPan, .snapZoom:
            return true
        default:
            return false
        }
    }

    /// The AlgorithmicOperation that executes this transition
    public var associatedOperation: AlgorithmicOperation? {
        switch self {
        case .none:
            return nil
        case .speedRamp:
            return .SpeedRamping
        case .beatSync:
            return .BeatMatchedCutGeneration
        default:
            return .TransitionGeneration
        }
    }
}

// MARK: - Audio Track Reference
/// Reference to an audio track that can be attached to a video template
@available(iOS 26, *)
public struct AudioTrackRef: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let source: AudioSource
    public let title: String
    public let duration: TimeInterval
    public let bpm: Float?
    public let moodTags: [String]
    public let genreTags: [String]
    public let volume: Float
    public let fadeInDuration: TimeInterval
    public let fadeOutDuration: TimeInterval
    public let loopable: Bool
    public let requiresLicense: Bool

    public init(
        id: String,
        source: AudioSource,
        title: String = "",
        duration: TimeInterval = 0,
        bpm: Float? = nil,
        moodTags: [String] = [],
        genreTags: [String] = [],
        volume: Float = 1.0,
        fadeInDuration: TimeInterval = 0,
        fadeOutDuration: TimeInterval = 0,
        loopable: Bool = false,
        requiresLicense: Bool = false
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.duration = duration
        self.bpm = bpm
        self.moodTags = moodTags
        self.genreTags = genreTags
        self.volume = volume
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.loopable = loopable
        self.requiresLicense = requiresLicense
    }

    public enum AudioSource: String, Codable, Sendable, Hashable {
        case original = "original"       // Original audio from source media
        case library = "library"          // From ENVI's bundled music library
        case aiGenerated = "ai_generated" // Generated by AIMusicGeneration operation
        case ambient = "ambient"          // Generated by AmbientSoundscape operation
        case sfx = "sfx"                  // Generated by SoundEffectGeneration operation
        case voiceover = "voiceover"      // Generated by VoiceoverGeneration or VoiceCloneNarration
        case external = "external"        // User-provided external track
    }
}

// MARK: - Video Template Operation Slot
/// A slot in a VideoTemplate that references an AlgorithmicOperation with optional parameters
@available(iOS 26, *)
public struct OperationSlot: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let operation: AlgorithmicOperation
    public let slotIndex: Int
    public let isEnabled: Bool
    public let parameters: [String: OperationParameterValue]
    public let transitionType: TransitionType?
    public let audioTrack: AudioTrackRef?
    public let timeRange: ClosedRange<TimeInterval>?

    public init(
        id: String,
        operation: AlgorithmicOperation,
        slotIndex: Int,
        isEnabled: Bool = true,
        parameters: [String: OperationParameterValue] = [:],
        transitionType: TransitionType? = nil,
        audioTrack: AudioTrackRef? = nil,
        timeRange: ClosedRange<TimeInterval>? = nil
    ) {
        self.id = id
        self.operation = operation
        self.slotIndex = slotIndex
        self.isEnabled = isEnabled
        self.parameters = parameters
        self.transitionType = transitionType
        self.audioTrack = audioTrack
        self.timeRange = timeRange
    }
}

// MARK: - Operation Parameter Value
/// Type-erased parameter value for operation slots
@available(iOS 26, *)
public enum OperationParameterValue: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case color(Double, Double, Double, Double) // RGBA
    case point(Double, Double)
    case size(Double, Double)
    case rect(Double, Double, Double, Double)
    case transition(TransitionType)
    case audioRef(String) // AudioTrackRef ID

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(["string": v])
        case .int(let v): try container.encode(["int": v])
        case .double(let v): try container.encode(["double": v])
        case .bool(let v): try container.encode(["bool": v])
        case .color(let r, let g, let b, let a): try container.encode(["color": [r, g, b, a]])
        case .point(let x, let y): try container.encode(["point": [x, y]])
        case .size(let w, let h): try container.encode(["size": [w, h]])
        case .rect(let x, let y, let w, let h): try container.encode(["rect": [x, y, w, h]])
        case .transition(let t): try container.encode(["transition": t.rawValue])
        case .audioRef(let id): try container.encode(["audioRef": id])
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: CodableValue].self)
        guard let (key, value) = dict.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                    debugDescription: "Invalid OperationParameterValue")
            )
        }
        switch key {
        case "string": self = .string(try value.decode())
        case "int": self = .int(try value.decode())
        case "double": self = .double(try value.decode())
        case "bool": self = .bool(try value.decode())
        case "color":
            let arr = try value.decode([Double].self)
            self = .color(arr[0], arr[1], arr[2], arr[3])
        case "point":
            let arr = try value.decode([Double].self)
            self = .point(arr[0], arr[1])
        case "size":
            let arr = try value.decode([Double].self)
            self = .size(arr[0], arr[1])
        case "rect":
            let arr = try value.decode([Double].self)
            self = .rect(arr[0], arr[1], arr[2], arr[3])
        case "transition":
            let raw = try value.decode(String.self)
            guard let t = TransitionType(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                        debugDescription: "Unknown TransitionType: \(raw)")
                )
            }
            self = .transition(t)
        case "audioRef": self = .audioRef(try value.decode())
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                    debugDescription: "Unknown parameter type: \(key)")
            )
        }
    }

    // Helper for decoding nested codable values
    private struct CodableValue: Decodable {
        let value: Any

        func decode<T: Decodable>() throws -> T {
            // Re-encode and decode to the target type
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(self) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Cannot encode value")
                )
            }
            return try JSONDecoder().decode(T.self, from: data)
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let v = try? container.decode(String.self) {
                self.value = v
            } else if let v = try? container.decode(Double.self) {
                self.value = v
            } else if let v = try? container.decode(Int.self) {
                self.value = v
            } else if let v = try? container.decode(Bool.self) {
                self.value = v
            } else if let v = try? container.decode([Double].self) {
                self.value = v
            } else if let v = try? container.decode([String: CodableValue].self) {
                self.value = v
            } else if let v = try? container.decode([CodableValue].self) {
                self.value = v
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                        debugDescription: "Cannot decode value")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let v = value as? String { try container.encode(v) }
            else if let v = value as? Double { try container.encode(v) }
            else if let v = value as? Int { try container.encode(v) }
            else if let v = value as? Bool { try container.encode(v) }
            else if let v = value as? [Double] { try container.encode(v) }
            else {
                throw EncodingError.invalidValue(value as Any,
                    EncodingError.Context(codingPath: encoder.codingPath,
                        debugDescription: "Cannot encode value"))
            }
        }
    }
}

// MARK: - Video Template
/// A video template definition with operation slots, transitions, and audio references
/// Integrates with TemplateRegistry.TemplateDefinition while adding slot-level detail
@available(iOS 26, *)
public struct VideoTemplate: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let version: String
    public let operationSlots: [OperationSlot]
    public let defaultTransition: TransitionType
    public let defaultAudioTrack: AudioTrackRef?
    public let templateDefinitionID: String? // Links to TemplateRegistry.TemplateDefinition.id

    public init(
        id: String,
        name: String,
        description: String = "",
        version: String = "1.0",
        operationSlots: [OperationSlot] = [],
        defaultTransition: TransitionType = .crossDissolve,
        defaultAudioTrack: AudioTrackRef? = nil,
        templateDefinitionID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.operationSlots = operationSlots
        self.defaultTransition = defaultTransition
        self.defaultAudioTrack = defaultAudioTrack
        self.templateDefinitionID = templateDefinitionID
    }

    /// All transition types used across this template's operation slots
    public var transitions: [TransitionType] {
        let explicit = operationSlots.compactMap(\.transitionType)
        if !explicit.isEmpty || defaultTransition != .none {
            return Array(Set(explicit + [defaultTransition]))
        }
        return []
    }

    /// All audio tracks referenced by this template
    public var audioTracks: [AudioTrackRef] {
        let slotTracks = operationSlots.compactMap(\.audioTrack)
        let tracks = slotTracks + (defaultAudioTrack.map { [$0] } ?? [])
        return Array(Set(tracks))
    }

    /// All operations this template requires (deduplicated, ordered by slot index)
    public var operations: [AlgorithmicOperation] {
        operationSlots
            .filter(\.isEnabled)
            .sorted { $0.slotIndex < $1.slotIndex }
            .map(\.operation)
    }
}

// MARK: - Operation Descriptor
/// Full operation descriptor with metadata for execution planning
public struct OperationDescriptor: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let operation: AlgorithmicOperation
    public let category: OperationCategory
    public let description: String
    public let inputTypes: [MediaType]
    public let outputTypes: [MediaType]
    public let estimatedDuration: TimeInterval
    public let requiresNetwork: Bool
    public let fallbackOperation: AlgorithmicOperation?
    public let supportedTransitions: [TransitionType]
    public let compatibleAudioSources: [AudioTrackRef.AudioSource]

    @available(iOS 26, *)
    public init(
        operation: AlgorithmicOperation,
        description: String = "",
        inputTypes: [MediaType] = [.image],
        outputTypes: [MediaType] = [.image],
        estimatedDuration: TimeInterval = 0.5,
        requiresNetwork: Bool = false,
        fallbackOperation: AlgorithmicOperation? = nil,
        supportedTransitions: [TransitionType] = [],
        compatibleAudioSources: [AudioTrackRef.AudioSource] = []
    ) {
        self.id = operation.rawValue
        self.operation = operation
        self.category = operation.category
        self.description = description
        self.inputTypes = inputTypes
        self.outputTypes = outputTypes
        self.estimatedDuration = estimatedDuration
        self.requiresNetwork = requiresNetwork
        self.fallbackOperation = fallbackOperation
        self.supportedTransitions = supportedTransitions
        self.compatibleAudioSources = compatibleAudioSources
    }

    // Backward-compatible init for pre-iOS-26 callers
    public init(
        operation: AlgorithmicOperation,
        description: String = "",
        inputTypes: [MediaType] = [.image],
        outputTypes: [MediaType] = [.image],
        estimatedDuration: TimeInterval = 0.5,
        requiresNetwork: Bool = false,
        fallbackOperation: AlgorithmicOperation? = nil
    ) {
        self.id = operation.rawValue
        self.operation = operation
        self.category = operation.category
        self.description = description
        self.inputTypes = inputTypes
        self.outputTypes = outputTypes
        self.estimatedDuration = estimatedDuration
        self.requiresNetwork = requiresNetwork
        self.fallbackOperation = fallbackOperation
        self.supportedTransitions = []
        self.compatibleAudioSources = []
    }
}

// MARK: - Media Type
public enum MediaType: String, Codable, Sendable, Hashable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case livePhoto = "live_photo"
    case depthMap = "depth_map"
    case text = "text"
    case vector = "vector"
    case mask = "mask"
    case embedding = "embedding"
}

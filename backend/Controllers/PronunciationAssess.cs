
using backend.Controllers;
using backend.Models.Speech;
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.PronunciationAssessment;
using Microsoft.CognitiveServices.Speech.Audio;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.EntityFrameworkCore.Update.Internal;


namespace backend.Controllers;

public class PronunciationAssess
{
    protected readonly string _speechKey;
    protected readonly string _speechRegion;
    private readonly IConfiguration _configuration;

    public PronunciationAssess(IConfiguration config)
    {
        _configuration = config;
        _speechKey = config["AzureSpeech:Key"];
        //Console.WriteLine($"_speechKey {_speechKey}");
        _speechRegion = config["AzureSpeech:Region"];
        //Console.WriteLine($"_speechRegion {_speechRegion}");

        if (string.IsNullOrWhiteSpace(_speechKey) || string.IsNullOrWhiteSpace(_speechRegion))
        {
            throw new InvalidOperationException("Azure Speech credentials are missing from configuration.");
        }

    }
    
    private SpeechConfig CreateSpeechConfig()
    {
        var speechConfig = SpeechConfig.FromSubscription(_speechKey, _speechRegion);
        // TODO: language is hardcoded for now 
        speechConfig.SpeechRecognitionLanguage = "en-US";
        speechConfig.OutputFormat = OutputFormat.Detailed;
        return speechConfig;
    }
    

    public async Task<PAResult> GetResults(string filePath, string referenceText, string userId, Granularity granularity)
    {
        Console.WriteLine("Setting up Azure config...");
        var speechConfig = CreateSpeechConfig();

        Console.WriteLine("creating AudioConfig...");
        using var audioConfig = AudioConfig.FromWavFileInput(filePath);

        Console.WriteLine("Creating recognizer...");
        using var recognizer = new SpeechRecognizer(speechConfig, audioConfig);

        var pronunciationConfig = new PronunciationAssessmentConfig(
            referenceText,
            GradingSystem.HundredMark,
            granularity,
            enableMiscue: true);
        pronunciationConfig.NBestPhonemeCount = 5;
        pronunciationConfig.EnableProsodyAssessment();
        pronunciationConfig.PhonemeAlphabet = "IPA";
        pronunciationConfig.ApplyTo(recognizer);

        Console.WriteLine("Calling RecognizeOnceAsync...");
        var result = await recognizer.RecognizeOnceAsync();

        Console.WriteLine($"Result reason: {result.Reason}");

        if (result.Reason == ResultReason.Canceled)
        {
            var cancellation = CancellationDetails.FromResult(result);
            Console.WriteLine($"Azure Canceled: {cancellation.Reason}");
            Console.WriteLine($"ErrorCode: {cancellation.ErrorCode}");
            Console.WriteLine($"Details: {cancellation.ErrorDetails}");
            throw new Exception($"Azure canceled request: {cancellation.Reason}, {cancellation.ErrorCode}, {cancellation.ErrorDetails}");
        }
        string json = result.Properties.GetProperty(
            PropertyId.SpeechServiceResponse_JsonResult);  // << the full detailed blob :contentReference[oaicite:0]{index=0}


        Console.WriteLine("Received json");


        var pa = ParseJson(result, json);
        
        //returns only accuracy score for now
        return pa;
    }

    //parses results 
    private PAResult ParseJson(SpeechRecognitionResult result, string json)
    {
        

        dynamic root = JsonConvert.DeserializeObject(json);

        // Defensive checks
        if (root?.NBest == null || root.NBest.Count == 0 || root.NBest[0].Words == null)
            throw new InvalidOperationException("Pronunciation JSON does not contain word details.");

        var wordList = new List<WordAssessment>();

        foreach (var w in root.NBest[0].Words)
        {
            var phonemes = new List<PhonemeAssessment>();
            if (w.Phonemes != null)
            {
                foreach (var p in w.Phonemes)
                {
                    Console.WriteLine(JsonConvert.SerializeObject(p, Formatting.Indented));

                    var pa = new PhonemeAssessment
                    {
                        Phoneme = (string?)p.Phoneme,
                        AccuracyScore = (double?)(p.PronunciationAssessment?.AccuracyScore) ?? 0,
                        NBestPhonemes = new List<PhonemeConfusion>()

                    };
                    var nbestPhonemes = p.PronunciationAssessment?.NBestPhonemes as JArray;
                    if (nbestPhonemes != null)
                    {
                        foreach (var nb in nbestPhonemes)
                        {
                            pa.NBestPhonemes.Add(new PhonemeConfusion
                            {
                                Phoneme = (string?)nb["Phoneme"],
                                Score = (double?)nb["Score"] ?? 0
                            });
                        }
                    }
                    phonemes.Add(pa);
                }
            }
            wordList.Add(new WordAssessment
            {
                Word = (string)w.Word,
                AccuracyScore = (double?)(w.PronunciationAssessment?.AccuracyScore) ?? 0,
                ErrorType = (string)(w.PronunciationAssessment?.ErrorType) ?? "",
                /*
                Offset         = (long?)(w.Offset)    ?? 0,
                Duration       = (long?)(w.Duration)  ?? 0,
                */
                Phonemes = phonemes
            });

        }

        var overall = PronunciationAssessmentResult.FromResult(result);

        return new PAResult
        {
            RecognizedText = result.Text,
            AccuracyScore = overall.AccuracyScore,
            FluencyScore = overall.FluencyScore,
            PronunciationScore = overall.PronunciationScore,
            Words = wordList
        };
    }
}
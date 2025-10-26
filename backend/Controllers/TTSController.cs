using Microsoft.AspNetCore.Mvc;
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.Audio;
using System.IO;
using System.Threading.Tasks;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TTSController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private readonly string _speechKey;
        private readonly string _speechRegion;

        public TTSController(IConfiguration config)
        {
            _configuration = config; // fix typo "congig" → "config"
            _speechKey = config["AzureSpeech:Key"];
            _speechRegion = config["AzureSpeech:Region"];
            if (string.IsNullOrWhiteSpace(_speechKey) || string.IsNullOrWhiteSpace(_speechRegion))
            {
                throw new InvalidOperationException("Azure Speech credentials are missing from configuration.");
            }
        }

        private SpeechConfig CreateSpeechConfig()
        {
            var speechConfig = SpeechConfig.FromSubscription(_speechKey, _speechRegion);
            speechConfig.SpeechRecognitionLanguage = "en-US";
            speechConfig.OutputFormat = OutputFormat.Detailed;
            return speechConfig;
        }

        [HttpPost("speak")]
        public async Task<IActionResult> Speak([FromForm] string text)
        {
            Console.WriteLine("landed in azure tts service");

            if (string.IsNullOrWhiteSpace(text))
                return BadRequest("Text is required.");

            var speechConfig = CreateSpeechConfig();
            speechConfig.SpeechSynthesisVoiceName = "en-US-JennyNeural"; // neural voice
            speechConfig.SetSpeechSynthesisOutputFormat(SpeechSynthesisOutputFormat.Riff16Khz16BitMonoPcm);


            // Create a pull stream to capture the audio
            using var audioOutputStream = AudioOutputStream.CreatePullStream();
            using var audioConfig = AudioConfig.FromStreamOutput(audioOutputStream);
            using var synthesizer = new SpeechSynthesizer(speechConfig, audioConfig);

            // Wrap text in SSML if you want IPA phonemes
            string ssml = $@"
            <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>
                <voice name='en-US-JennyNeural'>
                    Try to say 
                    <phoneme alphabet='ipa' ph='{text}'>{text}</phoneme>
                </voice>
            </speak>";

            var result = await synthesizer.SpeakSsmlAsync(ssml);

            if (result.Reason == ResultReason.Canceled)
            {
                var cancellation = SpeechSynthesisCancellationDetails.FromResult(result);
                return StatusCode(500, $"TTS failed: {cancellation.Reason}, {cancellation.ErrorDetails}");
            }

            // Return the audio as WAV
            return File(result.AudioData, "audio/wav", "speech.wav");
        }
    }
}

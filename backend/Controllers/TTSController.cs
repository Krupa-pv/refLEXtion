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

        [HttpGet("speak")]
        public async Task<IActionResult> Speak([FromQuery] string text)
        {
            Console.WriteLine($"TTS request for: {text}");
            if (string.IsNullOrWhiteSpace(text))
                return BadRequest("Text is required.");

            var speechConfig = CreateSpeechConfig();
            speechConfig.SpeechSynthesisVoiceName = "en-US-JennyNeural";
            speechConfig.SetSpeechSynthesisOutputFormat(
                SpeechSynthesisOutputFormat.Audio24Khz48KBitRateMonoMp3
            );

            using var synthesizer = new SpeechSynthesizer(speechConfig, null);

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

            Console.WriteLine($"✅ Generated TTS audio: {result.AudioData.Length} bytes");

            // Return MP3 directly as streaming content
            return File(result.AudioData, "audio/mpeg");
        }


    }
}

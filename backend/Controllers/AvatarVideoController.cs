using Microsoft.AspNetCore.Mvc;
using Microsoft.CognitiveServices.Speech;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.Audio;
using System.IO;
using System.Threading.Tasks;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AvatarVideoController : ControllerBase
    {
        private readonly IConfiguration _config;

        public AvatarVideoController(IConfiguration config)
        {
            _config = config;
        }

        [HttpPost("generate")]
        public async Task<IActionResult> GenerateVideo([FromQuery] string glbUrl, [FromQuery] string text)
        {
            Console.WriteLine("⚡ AvatarVideoController hit!");

            if (string.IsNullOrWhiteSpace(glbUrl))
                return BadRequest("GLB URL is required.");
            if (string.IsNullOrWhiteSpace(text))
                return BadRequest("Text is required.");

            try
            {
                // 1️⃣ Generate audio + viseme data
                var (audioBytes, visemes) = await GenerateAudioWithVisemes(text);
                Console.WriteLine($"✅ Generated TTS audio: {audioBytes.Length} bytes, {visemes.Count} visemes");

                // 2️⃣ (Optional) Send visemes + GLB to NVIDIA / animation step
                // var videoBytes = await GenerateVideoFromAudio(glbUrl, audioBytes, visemes);

                // For now, just return viseme data + audio
                return Ok(new
                {
                    audioBase64 = Convert.ToBase64String(audioBytes),
                    visemes,
                    glbUrl
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error: {ex.Message}");
                return StatusCode(500, $"Failed to generate video: {ex.Message}");
            }
        }

        private async Task<(byte[] audioBytes, List<object> visemes)> GenerateAudioWithVisemes(string text)
        {
            var speechConfig = CreateSpeechConfig();
            speechConfig.SpeechSynthesisVoiceName = "en-US-JennyNeural";
            speechConfig.SetSpeechSynthesisOutputFormat(SpeechSynthesisOutputFormat.Audio24Khz48KBitRateMonoMp3);

            using var synthesizer = new SpeechSynthesizer(speechConfig, null);

            var visemeData = new List<object>();

            synthesizer.VisemeReceived += (s, e) =>
            {
                var visemeId = e.VisemeId;
                var offsetMs = e.AudioOffset / 10000; // convert to milliseconds
                visemeData.Add(new { visemeId, offsetMs });
                Console.WriteLine($"🫧 Viseme: {visemeId} at {offsetMs}ms");
            };

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
                throw new Exception($"TTS failed: {cancellation.Reason}, {cancellation.ErrorDetails}");
            }

            return (result.AudioData, visemeData);
        }

        private SpeechConfig CreateSpeechConfig()
        {
            var key = _config["AzureSpeech:Key"];
            var region = _config["AzureSpeech:Region"];
            return SpeechConfig.FromSubscription(key, region);
        }
    }
}

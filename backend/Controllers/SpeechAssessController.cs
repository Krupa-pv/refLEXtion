using Microsoft.AspNetCore.Mvc; // For ApiController, HttpPost, ControllerBase, IActionResult
using Microsoft.Extensions.Configuration; // For IConfiguration
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.PronunciationAssessment;
using Microsoft.CognitiveServices.Speech.Audio;
using System.IO; // For MemoryStream
using System.Linq; // For LINQ methods like Average
using System.Collections.Generic; // For List<T>
using backend.Models;
using backend.Models.Speech;
using System;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text.Json;
using System.Drawing.Printing;
using backend.Controllers;


namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SpeechAssessController : ControllerBase
    {
        private IConfiguration _configuration;
        private readonly string _speechKey;
        private readonly string _speechRegion;
        private PronunciationAssess _pronunciationAssess;

        public SpeechAssessController(IConfiguration configuration, PronunciationAssess pronunciationAssess)
        {
            _configuration = configuration;
            string databaseName = configuration["DatabaseName"];
            string containerName = configuration["ContainerName"];
            _pronunciationAssess = pronunciationAssess;

        }

        [HttpPost("assess")]
        public async Task<ActionResult<double>> AssessPronunciation(
            [FromForm] IFormFile audio,
            [FromForm] string referenceText,
            [FromForm] string? userId,
            [FromForm] string gradinglevel)
        {

            Console.WriteLine("landed in backend woohoo");

            if (audio == null || string.IsNullOrWhiteSpace(referenceText))
                return BadRequest("Audio and referenceText are required.");

            var tempFilePath = Path.GetTempFileName();
            
            if (!Enum.TryParse<Granularity >(gradinglevel, true, out var granularity))
            {
                return BadRequest($"Invalid grading level: {gradinglevel}");
            }

            try
            {
                Console.WriteLine("Saving uploaded audio file...");
                using (var stream = System.IO.File.Create(tempFilePath))
                {
                    await audio.CopyToAsync(stream);
                }

                Console.WriteLine($"File saved to: {tempFilePath}");
                Console.WriteLine($"Reference text: {referenceText}");
                Console.WriteLine("Calling Azure SDK...");



                var result = await _pronunciationAssess.GetResults(tempFilePath, referenceText, userId, granularity);

                Console.WriteLine("Overall Accuracy: " + result.AccuracyScore);
                Console.WriteLine("Words count: " + result.Words?.Count);
                foreach (var w in result.Words ?? new List<WordAssessment>())
                {
                    Console.WriteLine($"Word: {w.Word}, Phonemes: {string.Join(", ", w.Phonemes)}");
                }
                return Ok(result);


                Console.WriteLine("Azure assessment complete");
                return Ok(result);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"EXCEPTION: {ex}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
            finally
            {
                // Clean up temp file
                if (System.IO.File.Exists(tempFilePath))
                    System.IO.File.Delete(tempFilePath);
            }
        }


    }
}

    
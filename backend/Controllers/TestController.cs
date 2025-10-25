using Azure;
using Azure.AI.OpenAI;
using OpenAI.Chat;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

using System.Text.RegularExpressions;

[ApiController]
[Route("api/[controller]")]

public class TestController : ControllerBase
{
    private readonly ChatClient _chatClient;
    private readonly ILogger<TestController> _logger;

    
    
    public TestController(IConfiguration configuration)
    {
        
        /*string openAIUrl = configuration["OpenAIURL"];
        string keyCred = configuration["OpenAIKeyCred"];
        AzureOpenAIClient client = new AzureOpenAIClient(
            new Uri(openAIUrl),
            new Azure.AzureKeyCredential(keyCred)
        );
        _chatClient = client.GetChatClient("gpt-4o");*/

    }
    [HttpGet]
    public IActionResult Ping()
    {
        
        _logger.LogInformation("Flutter connecton");

        
        return Ok(new
        {
            ok = true,
            message = "Connection good",
            time = DateTime.UtcNow
        });
    }
    [HttpPost("generate_word")]
    public async Task<IActionResult> GenerateWord([FromBody] WordRequest request, CancellationToken cancellation = default)
    {


        // Construct the AI prompt
        var prompt = string.Empty;

        if (request.TroubleWords != null && request.TroubleWords.Any())
        {
            prompt = $@"
                    Generate practice words for a student in grade {request.Grade}.
                    The student struggles with the following trouble words: {string.Join(", ", request.TroubleWords)}.
                    Student has a {request.ReadingLevel} reading level and interests in {request.Interests}
                    Words should be appropriate for the student's age and designed to improve verbal skills and pronunciation.
                    Student wants to attempt words that are {request.Difficulty} for their current level.
                    Include words of varying lengths to challenge the student appropriately. Inlude only the list of words.";
        }
        else
        {
            prompt = $@"
                    Generate practice words for a student in grade {request.Grade}.
                    The student has a {request.ReadingLevel} reading level and interests in {request.Interests}.
                    Words should be appropriate for the student's age and designed to improve verbal skills and pronunciation.
                    Student wants to attempt words that are {request.Difficulty} for their current level. 
                    Include words of varying lengths to challenge the student appropriately. Inlude only the list of words. ";
        }



        ChatCompletionOptions opts = new()
        {

            MaxOutputTokenCount = 8_000,
            Temperature = 0.7f,
            FrequencyPenalty = 0.0f,
            PresencePenalty = 0.0f,
            TopP = 1.0f
        };

        var updates = _chatClient.CompleteChatStreamingAsync(
                messages:
                [
                    new SystemChatMessage("You are a speaking tutor specializing in improving verbal skills such as pronunciation by generating words."),
            new UserChatMessage(prompt)
                ],
                options: opts,
                cancellationToken: cancellation);



        var storyBuilder = new System.Text.StringBuilder();
        await foreach (var update in updates.WithCancellation(cancellation))
        {
            foreach (var part in update.ContentUpdate)
            {
                storyBuilder.Append(part.Text);
            }
        }
        string story = storyBuilder.ToString();

        if (string.IsNullOrWhiteSpace(story))
            return BadRequest(new { error = "No words generated." });

        // Extract words (handles "1. Elf", "2) Wand", dash bullets, or plain lines)
        var words = Regex.Matches(story, @"(?:^\s*[-*]?\s*|\b\d+\s*[\.\)]\s*)([A-Za-z][A-Za-z'-]*)", RegexOptions.Multiline)
                        .Cast<Match>()
                        .Select(m => m.Groups[1].Value.Trim())
                        .Where(w => !string.IsNullOrWhiteSpace(w))
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .Take(50) // safety cap
                        .ToList();

        return Ok(new { words });

    }
}

public class WordRequest{
        public string UserId { get; set; } 
        public string Grade { get; set; } 
        public string ReadingLevel { get; set; } 
        public string Interests { get; set; } 
        public string Difficulty { get; set; } 
        public List<string> TroubleWords { get; set; } // The trouble words of the user determined by wordspeak
    }




using Microsoft.Azure.Cosmos;
using Azure;
using Azure.AI.OpenAI;

using backend.Controllers;

var builder = WebApplication.CreateBuilder(args);



builder.Services.AddControllers();
builder.Logging.ClearProviders();
builder.Logging.AddConsole();


builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSingleton(sp =>
{

    var cfg = builder.Configuration;
    var url = new Uri(cfg["OpenAIURL"]);
    var keycred = new AzureKeyCredential(cfg["OpenAIKeyCred"]);
    return new AzureOpenAIClient(url, keycred);
});

builder.Services.AddSingleton<PronunciationAssess>();
// or AddScoped<PronunciationAssess>() if you want one per request

var app = builder.Build();




app.UseAuthorization();
app.UseCors();
app.MapControllers();
app.Run();
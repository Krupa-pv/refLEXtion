
using Microsoft.Azure.Cosmos;
using Azure;
using Azure.AI.OpenAI;



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

var app = builder.Build();




app.UseAuthorization();
app.UseCors();
app.MapControllers();
app.Run();
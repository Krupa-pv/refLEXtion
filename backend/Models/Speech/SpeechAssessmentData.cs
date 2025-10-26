namespace backend.Models.Speech;

public class SpeechAssessmentData
{
    public List<PAResult> Feedback { get; set; } = new List<PAResult>();
    public List<TroubleWord> TroubleWords { get; set; } = new List<TroubleWord>();
}

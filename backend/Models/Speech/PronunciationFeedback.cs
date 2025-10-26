namespace backend.Models.Speech;

public class PAResult
{
    public string RecognizedText { get; set; }
    public double AccuracyScore { get; set; }
    public double FluencyScore { get; set; }
    public double PronunciationScore { get; set; }
    public List<WordAssessment> Words { get; set; }
}

public class WordAssessment
{
    public string Word { get; set; }
    public double AccuracyScore { get; set; }
    public string ErrorType { get; set; }
    /*dont need these fields for now
    public long Offset { get; set; }
    public long Duration { get; set; }*/
    public List<PhonemeAssessment> Phonemes { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}


public class PhonemeAssessment
{
    public string Phoneme { get; set; }
    public double AccuracyScore { get; set; }
    public List<PhonemeConfusion> NBestPhonemes {get; set;}
}

public class PhonemeConfusion
{
    public string Phoneme { get; set; }
    public double Score { get; set; }
}


public class PhonemeProfileEntry
{
    public string Phoneme { get; set; }
    public int TotalAttempts { get; set; }
    public double AverageAccuracy { get; set; }
    public double LastAccuracy { get; set; }
    public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
    public List<PhonemeConfusion> CommonConfusions { get; set; } = new();

}

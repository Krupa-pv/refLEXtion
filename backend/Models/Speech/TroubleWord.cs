namespace backend.Models.Speech;

public class TroubleWord
{
    public string Word { get; set; } // The trouble word itself
    public int Frequency { get; set; } // How many times it was mispronounced
    public DateTime LastEncountered { get; set; } // When it was last encountered
}
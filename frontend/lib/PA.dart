enum GradingLevel
{
    Phoneme,
    Word,
    FullText
}

/*usage: 
Granularity granularity = Granularity.Phoneme;
String granularityStr = granularity.name;
*/

extension GradingLevelString on GradingLevel {
  String get name => toString().split('.').last;
}

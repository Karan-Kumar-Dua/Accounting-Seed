@IsTest
public class NumberToWordsTest {

    @IsTest
    public static void testNumberToWords() {
        System.assertEquals(' ' + Label.COMMON_TWO_THOUSAND_THREE_HUNDRED_FORTY_FIVE, NumberToWords.digitFinder(2345,0));
    }

}
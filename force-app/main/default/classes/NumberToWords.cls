public with sharing class NumberToWords {
    // Add all posible words in list
    public static List<String> ones = new List<String> {
        '', ' ' + Label.COMMON_ONE, ' ' + Label.COMMON_TWO, ' ' + Label.COMMON_THREE, ' ' + Label.COMMON_FOUR, ' ' + Label.COMMON_FIVE, ' ' + Label.COMMON_SIX, ' ' + Label.COMMON_SEVEN, ' ' + Label.COMMON_EIGHT, ' ' + Label.COMMON_NINE, ' ' + Label.COMMON_TEN, ' ' + Label.COMMON_ELEVEN,
        ' ' + Label.COMMON_TWELVE, ' ' + Label.COMMON_THIRTEEN, ' ' + Label.COMMON_FOURTEEN, ' ' + Label.COMMON_FIFTEEN, ' ' + Label.COMMON_SIXTEEN, ' ' + Label.COMMON_SEVENTEEN, ' ' + Label.COMMON_EIGHTEEN, ' ' + Label.COMMON_NINETEEN
    };

    public static List<String> tens = new List<String> {
        '', '', ' ' + Label.COMMON_TWENTY, ' ' + Label.COMMON_THIRTY, ' ' + Label.COMMON_FORTY, ' ' + Label.COMMON_FIFTY, ' ' + Label.COMMON_SIXTY, ' ' + Label.COMMON_SEVENTY, ' ' + Label.COMMON_EIGHTY, ' ' + Label.COMMON_NINETY
    };

    public static List<String> triplets = new List<String> {
        '', ' ' + Label.COMMON_THOUSAND, ' ' + Label.COMMON_MILLION, ' ' + Label.COMMON_BILLION, ' ' + Label.COMMON_TRILLION, ' ' + Label.COMMON_QUADRILLION, ' ' + Label.COMMON_QUINTILLION,
        ' ' + Label.COMMON_SEXTILLION, ' ' + Label.COMMON_SEPTILLION, ' ' + Label.COMMON_OCTILLION, ' ' + Label.COMMON_NONILLION
    };
            
    public static String digitFinder(Integer num, Integer tri) {
        //traceStmts('What is the amount:' + num + ' Tries = '+ tri);
        
        String str = '';
        // Find the given number has any thousands
        Integer r = Math.round((num/1000));
        // Find the number of hudreds are available in the given amount
        Integer x = Math.Mod(Math.round((num/100)), 10);
        // Find the ones/tens in the given amount
        Integer y = Math.round((Math.Mod(num, 100)));

        
        // If any 100's found in the amount, then it will convert this into word first.
        if (x > 0) {
            str = ones[x] + ' ' + Label.COMMON_HUNDRED;
        }
        // Then, find the ones ane tens in the amount.    
        if (y < 20) {
            str += ones[y];

        } 
        else {
            str += tens[Math.round((y / 10))] + ones[Math.Mod(y, 10)];

        }
        // Indirectly convert the thousands into word, if any found in this mehtod parameter.
        if (str != '') {
            str += triplets[tri];

        }
        // As per the above Modulus, if any tousands found call the same function once again until r=0.
        if (r > 0) {
            return digitFinder(r, tri + 1) + str;
        }
        return str ;
    }

}
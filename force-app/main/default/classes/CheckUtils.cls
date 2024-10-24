public with sharing class CheckUtils {
    
    private static final String WORDS_ZERO = Label.INF_WORDS_ZERO;
    private static final String WORDS_DENOMINATOR = Label.INF_WORDS_DENOMINATOR;
    private static final String WORDS_AND = Label.COMMON_AND;
    private static final String ZERO = '0';

    public static String toWords(Decimal amt) {
        if (amt == null) {
            return null;
        }
        else if (amt == 0) {
            return WORDS_ZERO;
        }
        else if (Math.abs(amt) > 0) {
            Decimal d = Math.abs(amt);
            Integer i = d.intValue();

            String words = NumberToWords.digitFinder(i, 0);

            String fractionalDigits = (d - i).setScale(2, System.RoundingMode.HALF_UP).toPlainString();
            fractionalDigits = fractionalDigits.subString(2, fractionalDigits.length());
            fractionalDigits += fractionalDigits.length() == 1 ? ZERO : '';

            if (String.isNotBlank(words)) {
                return words + ' ' + WORDS_AND + ' ' + fractionalDigits + WORDS_DENOMINATOR;
            } 
            else if (String.isBlank(words)) {
                return fractionalDigits + WORDS_DENOMINATOR;
            } 
        } 
        return null;
    }

    public static Decimal getNextCheckNumber(Id bankAccountId) {
        Decimal maxForCR = 0;
        Decimal maxForCD = 0;
        if (getQueryLimit() > DomainUtils.getCountCheckNumberForCashReceipts()) {
            for (AggregateResult aggRes : DomainUtils.getMaxCheckNumberForCashReceipts(new Set<Id>{bankAccountId})) {
                Id glAccount = (Id) aggRes.get('bankAccountId');
                if (glAccount == bankAccountId) {
                    maxForCR = (Decimal) aggRes.get('maxCheckNumber');
                }
            }
        }
        else {
            maxForCR = DomainUtils.getLastCheckNumberForCashReceipts(bankAccountId);
        }

        if (getQueryLimit() > DomainUtils.getCountCheckNumberForCashDisbursements()) {
            for (AggregateResult aggRes : DomainUtils.getMaxCheckNumberForCashDisbursements(new Set<Id>{bankAccountId})) {
                Id glAccount = (Id) aggRes.get('bankAccountId');
                if (glAccount == bankAccountId) {
                    maxForCD = (Decimal) aggRes.get('maxCheckNumber');
                }
            }
        }
        else {
            maxForCD = DomainUtils.getLastCheckNumberForCashDisbursements(bankAccountId);
        }

        return (maxForCD > maxForCR) ? maxForCD + 1 : maxForCR + 1;
    }
    
    private static Integer getQueryLimit() {
        return Test.isRunningTest() ? 
            50 : Limits.getLimitQueryRows() - Limits.getQueryRows(); 
    }
    
}
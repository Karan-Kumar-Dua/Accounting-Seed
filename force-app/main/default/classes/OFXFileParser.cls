public with sharing class OFXFileParser extends AbstractFileParser {

    public static final String FILE_FORMAT_ERROR = Label.ERR_FILE_FORMAT;
    public static final String ACCOUNT_TYPE_ERROR = Label.ERR_ACCOUNT_TYPE; 

    private static final String OFX_START_TAG = '<OFX>';
    private static final String OFX_END_TAG = '</OFX>';

    private String id;
    private String name;
    private String memo;
    private String transType;
    private Date transDate;
    private Decimal amount;
    private String accountType;
    private String checkNumber;

    public List<BDCTransaction> transactionModels;
    public String financialInstitutionId;
    public String financialInstitutionName;
    public String accountId;
    public String transCurrency;

    public class OFXFileParserException extends AbstractFileParserException {}
    
    public OFXFileParser(String file) {
        this.file = file == NULL ? '' : file;
        setControlAccount();
    }
    
    public override Integer getTransactionCount() {
        Integer lineCount;

        try {
            lineCount = file.countMatches('<STMTTRN>');
        } 
        catch (Exception ex) {
            lineCount = -1;
        } 
              
        return lineCount;
    }
    
    public override Boolean isValidFileFormat() {
        Boolean retVal = false;
        try {
            Integer startTagIndex = file.indexOf(OFX_START_TAG);
            Integer endTagIndex = file.indexOf(OFX_END_TAG);
            retVal = startTagIndex > 0 && endTagIndex > 0 && startTagIndex < endTagIndex ? true : false;
        }
        catch (Exception ex) {

        }
        return retVal;
    }
 
    public override String getFileFormatErrorMessage() {
        return FILE_FORMAT_ERROR;
    }

    public String extractCurrency() {
        Integer startIndex = file.indexOf('<CURDEF>');
        Integer endIndex = file.indexOf('<', startIndex + 1);
        String result = file.subString(startIndex, endIndex);
        if (!String.isEmpty(result)) {
            result = result.remove('<CURDEF>');
            result = result.trim();
        }
        return result;
    }

    public String extractFinancialInstitutionId() {
        String result;
        Integer startIndex = file.indexOf('<FID>');
        if (startIndex != -1) {
            Integer endIndex = file.indexOf('<', startIndex + 1);
            result = file.subString(startIndex, endIndex);
            if (!String.isEmpty(result)) {
                result = result.remove('<FID>');
                result = result.trim();
            }
        }
        return result;
    }

    public String extractFinancialInstitutionName() {
        String result;
        Integer startIndex = file.indexOf('<ORG>');
        if (startIndex != -1) {
            Integer endIndex = file.indexOf('<', startIndex + 1);
            result = file.subString(startIndex, endIndex);
            if (!String.isEmpty(result)) {
                result = result.remove('<ORG>');
                result = result.trim();
            }
        }
        return result;
    }

    public String extractAccountId() {
        Integer startIndex = file.indexOf('<ACCTID>');
        Integer endIndex = file.indexOf('<', startIndex + 1);
        String result = file.subString(startIndex, endIndex);
        if (!String.isEmpty(result)) {
            result = result.remove('<ACCTID>');
            result = result.trim();
        }
        return result;
    }

    public String extractAccountType() {
        String result;
        //Credit Card Account - return: [creditCard]
        if (file.indexOf('<CCACCTFROM>') != -1) {
            result = 'creditCard';
        }//Banking Account - return value: [CHECKING / SAVINGS / MONEYMRKT / CREDITLINE]
        else if (file.indexOf('<BANKACCTFROM>') != -1) {
            Integer startIndex = file.indexOf('<ACCTTYPE>');
            Integer endIndex = file.indexOf('<', startIndex + 1);
            result = file.subString(startIndex, endIndex);
            if (!String.isEmpty(result)) {
                result = result.remove('<ACCTTYPE>');
                result = result.trim();
            }

        }
        else {
            throw new OFXFileParserException(ACCOUNT_TYPE_ERROR);
        }
        return result;
    }

    private void clearTransactionFields() {
        id = NULL;
        name = NULL;
        transType = NULL;
        transDate = NULL;
        amount = NULL;
        memo = NULL;
        checkNumber = NULL;
    }

    public void parseToTransactionModels() {
        try {
            transactionModels = new List<BDCTransaction>();
            //get Account Type from the file
            //we expect either 'bank' or 'creditCard' or exception thrown
            accountType = extractAccountType();
            //get currency from the file
            transCurrency = extractCurrency();
            //get Financial Institution Id from the file
            financialInstitutionId = extractFinancialInstitutionId();
            //get Financial Institution Name from the file
            financialInstitutionName = extractFinancialInstitutionName();
            //get Account Id from the file
            accountId = extractAccountId();

            Integer startIndex = file.indexOf('<STMTTRN>');
            if (startIndex == -1) {
                return;
            }
            Integer endIndex = file.indexOf('<', startIndex + 1);
            Pattern startStatementPattern = Pattern.compile('[ \t\r\n]*<STMTTRN>[ \t\r\n]*');
            Pattern typePattern = Pattern.compile('[ \t\r\n]*<TRNTYPE>([\\w]+)[ \t\r\n]*');
            Pattern datePattern = Pattern.compile('[ \t\r\n]*<DTPOSTED>(\\d\\d\\d\\d)(\\d\\d)(\\d\\d).*[ \t\r\n]*');
            Pattern amountPattern =
                Pattern.compile('[ \t\r\n]*<TRNAMT>([+-]?[0-9]{1,3}(?:[0-9]*(?:[.,][0-9]{1,})?|(?:,[0-9]{3})*(?:\\.[0-9]{1,})?|(?:\\.[0-9]{3})*(?:,[0-9]{1,})?))[ \t\r\n]*');
            Pattern idPattern = Pattern.compile('[ \t\r\n]*<FITID>(.*)[ \t\r\n]*');
            Pattern namePattern = Pattern.compile('[ \t\r\n]*<NAME>(.+)[ \t\r\n]*');
            Pattern memoPattern = Pattern.compile('[ \t\r\n]*<MEMO>(.+)[ \t\r\n]*');
            Pattern checkNumPattern = Pattern.compile('[ \t\r\n]*<CHECKNUM>(.+)[ \t\r\n]*');

            while (endIndex > 0) {

                String line = file.subString(startIndex, endIndex);
                Matcher startStatementMatcher = startStatementPattern.matcher(line);
                Matcher typeMatcher = typePattern.matcher(line);
                Matcher dateMatcher = datePattern.matcher(line);
                Matcher amountMatcher = amountPattern.matcher(line);
                Matcher idMatcher = idPattern.matcher(line);
                Matcher nameMatcher = namePattern.matcher(line);
                Matcher memoMatcher = memoPattern.matcher(line);
                Matcher checkNumMatcher = checkNumPattern.matcher(line);

                if (startStatementMatcher.matches()) {
                    if (id != NULL && transDate != NULL && amount != NULL && amount != 0) {
                        transactionModels.add(
                            new BDCTransaction(
                                id,
                                transDate,
                                amount, 
                                transCurrency,
                                transType,
                                accountId,
                                accountType,
                                name,
                                memo,
                                checkNumber
                            )
                        );
                        clearTransactionFields();
                    }
                }
                else if (dateMatcher.matches()) {
                    transDate = Date.newInstance(Integer.valueOf(dateMatcher.group(1)), Integer.valueOf(dateMatcher.group(2)), Integer.valueOf(dateMatcher.group(3)));
                }
                else if (amountMatcher.matches()) {
                    transType = amountMatcher.group(1).contains('-') ? 'DEBIT' : 'CREDIT';
                    //For the new BDC we use only positive amount
                    amount = getAmount(amountMatcher.group(1)).abs();
                }
                else if (idMatcher.matches()) {
                    id = idMatcher.group(1);
                }
                else if (checkNumMatcher.matches()) {
                    checkNumber = checkNumMatcher.group(1);
                }
                else if (nameMatcher.matches()) {
                    name = nameMatcher.group(1).unescapeHtml4();
                }
                else if (memoMatcher.matches()) {
                    memo = memoMatcher.group(1).unescapeHtml4();
                }

                startIndex = endIndex;
                endIndex = file.indexOf('<', startIndex + 1);
            }

            if (id != NULL && transDate != NULL && amount != NULL && amount != 0) {
                transactionModels.add(
                    new BDCTransaction(
                        id,
                        transDate,
                        amount, 
                        transCurrency,
                        transType,
                        accountId,
                        accountType,
                        name,
                        memo,
                        checkNumber
                    )
                );
            }
        }
        catch (OFXFileParserException ofxEx) {
            throw ofxEx;
        }
        catch (Exception ex) {
            throw new OFXFileParserException(FILE_FORMAT_ERROR);
        }
    }

    public override List<FinancialImportLineWrapper> parse() {
        return lineWrapperList;
    }

    @TestVisible
    private Decimal getAmount(String amountString) {
        Decimal amount = 0;

        if (amountString.IndexOfAny('.,') != -1) {
            Integer lastIndex = amountString.lastIndexOf('.') != -1 ? amountString.lastIndexOf('.') : amountString.lastIndexOf(',');
            String dollars = amountString.substring(0, lastIndex);
            String cents = amountString.substring(lastIndex + 1, amountString.length());

            amount = Decimal.valueOf(dollars.replaceAll(',', '').replaceAll('\\.', ''));

            if (!amountString.startsWith('-') && !String.isBlank(cents)) {
                amount += Decimal.valueOf(cents)/Math.pow(10, cents.length());
            }
            else if (amountString.startsWith('-') && !String.isBlank(cents)) {
                amount -= Decimal.valueOf(cents)/Math.pow(10, cents.length());
            }

        }
        else {
            amount = Decimal.valueOf(amountString);
        }
        return amount.setScale(2, System.RoundingMode.HALF_UP);
    }
}
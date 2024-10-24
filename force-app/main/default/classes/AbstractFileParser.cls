public with sharing abstract class AbstractFileParser implements FileParser {
    protected List<FinancialImportLineWrapper> lineWrapperList;
    protected Accounting_Settings__c main;
    protected String file;
    public final String FILE_FORMAT_ERROR;
    public abstract class AbstractFileParserException extends Exception {}
     
    protected void setControlAccount() {
        main = AccountingSettingsHandler.getAccountingSettings();
    }
            
    public abstract Integer getTransactionCount();
    
    public abstract Boolean isValidFileFormat();
    
    public abstract String getFileFormatErrorMessage();
    
    public abstract List<FinancialImportLineWrapper> parse();
}
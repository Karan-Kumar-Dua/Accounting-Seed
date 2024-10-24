public interface FileParser {
    Integer getTransactionCount();
    List<FinancialImportLineWrapper> parse();
    Boolean isValidFileFormat();
    String getFileFormatErrorMessage();
}
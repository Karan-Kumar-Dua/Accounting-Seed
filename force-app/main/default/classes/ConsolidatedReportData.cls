public interface ConsolidatedReportData {
    AcctSeedReportData convertValue(String colValue);
    void setLabel(String columnValueLabel);
    void setColumnName(String columnName);  
}
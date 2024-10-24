public with sharing class AcctSeedReportDataToCurrency implements ConsolidatedReportData {
    @TestVisible
    private AcctSeedReportData reportData;
    private String columnName;
    private String columnValueLabel;

    public AcctSeedReportDataToCurrency() { }

    public void setColumnName(String columnName) {
       this.columnName = columnName;
    }

    public void setLabel(String columnValueLabel) {
        this.columnValueLabel = columnValueLabel;
    }

    public AcctSeedReportData convertValue(String colValue){
        Reports.ReportCurrency reportCurrency = (Reports.ReportCurrency) JSON.deserialize(colValue, Reports.ReportCurrency.class); 
        reportData = new AcctSeedReportData();
        reportData.setColumnName(this.columnName);
        reportData.setLabel(this.columnValueLabel);
        reportData.setValue(String.valueof(reportCurrency.getAmount()));
        reportData.setCurrency(reportCurrency.getCurrencyCode());
        return reportData;
    }

}
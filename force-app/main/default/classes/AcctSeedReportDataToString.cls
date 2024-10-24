public with sharing class AcctSeedReportDataToString implements ConsolidatedReportData {
    @TestVisible
    private AcctSeedReportData reportData;
    private String columnName;
    private String columnValueLabel;
    private String columnValue;

    public AcctSeedReportDataToString() { }

    public void setColumnName(String columnName) {
       this.columnName = columnName;
    }

    public void setLabel(String columnValueLabel) {
        this.columnValueLabel = columnValueLabel;
    }

    private void setValue(String columnValue) {
        this.columnValue = columnValue;
    }

    public AcctSeedReportData convertValue(String colValue){
        setValue(colValue);
        reportData = new AcctSeedReportData();
        reportData.setValue(this.columnValue);
        reportData.setColumnName(this.columnName);
        reportData.setLabel(this.columnValueLabel);
        return reportData;
    }

}
public with sharing class AcctSeedReportData {
    //variable used to hold columnName of report to which data is stored here
    public String columnName;
    //label of Specific column value
    public String label;
    //Value of Specific column value
    Public String value;
    //currency of Specific column value if any and defualt to null;
    Public String currncy = null;

    public AcctSeedReportData() { }

    public void setColumnName(String columnName) {
        this.columnName = columnName;
    }

    public void setLabel(String label) {
        this.label = label;
    }

    public void setValue(String value) {
        this.value = value;
    }

    public void setCurrency(String currncy) {
        this.currncy = currncy;
    }

}
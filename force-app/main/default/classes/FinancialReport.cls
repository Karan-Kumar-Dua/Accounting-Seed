public interface FinancialReport {
    FinancialReportWrapper runReport(FinancialReportOptions fro);
    FinancialReportWrapper createReportDefinition();
}
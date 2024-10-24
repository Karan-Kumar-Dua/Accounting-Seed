public with sharing class TaxServiceResult {
    public Boolean isSuccess {
        get {
            return isSourceDocsSuccess() && isAvaTaxCalculationSuccess();
        }
        set;
    }
    public List<TaxServiceResultLine> sourceDocs = new List<TaxServiceResult.TaxServiceResultLine>();
    public AvaTaxHelper.AvaTaxCalculationResult avaTaxCalcResult;

    private Boolean isSourceDocsSuccess() {
        if (!sourceDocs.isEmpty()) {
            for (TaxServiceResultLine line : sourceDocs) {
                if (!line.isSuccess) {
                    return false;
                }
            }
        }
        return true;
    }

    private Boolean isAvaTaxCalculationSuccess() {
        if (avaTaxCalcResult != null) {
            for (AvaTaxHelper.AvaTaxCalculationReport report : avaTaxCalcResult.reportMap.values()) {
                if (!report.isSuccess) {
                    return false;
                }
            }
        }
        return true;
    }

    public with sharing class TaxServiceResultLine {
        public Boolean isSuccess;
        public TaxServiceResultLineErrors errors = new TaxServiceResultLineErrors();
        public SObject sourceObj;
        public List<SObject> sourceObjLines;
    }

    public class TaxServiceResultLineErrors {
        public List<TaxServiceResultLineErrorItem> items;

        public TaxServiceResultLineErrors() {
            this.items = new List<TaxServiceResultLineErrorItem>();
        }

        public void add(String message) {
            this.items.add(new TaxServiceResultLineErrorItem(message, ApexPages.Severity.ERROR.name()));
        }

        public void add(String message, String code) {
            this.items.add(new TaxServiceResultLineErrorItem(message, code));
        }

        public Boolean isEmpty() {
            return this.items.isEmpty();
        }
    }

    public class TaxServiceResultLineErrorItem {
        public String message;
        public String code;

        public TaxServiceResultLineErrorItem(String message, String code) {
            this.message = message;
            this.code = code;
        }
    }
}
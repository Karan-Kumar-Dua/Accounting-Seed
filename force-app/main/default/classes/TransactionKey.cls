public with sharing class TransactionKey {

    public TransactionKey(Transaction__c trxn){
        this.sourceDocumentId = getSourceDocumentId(trxn);
        this.secondSourceDocumentId = getSecondSourceDocumentId(trxn);
        this.ledgerId = trxn.Ledger__c;
        this.periodId = trxn.Accounting_Period__c;
        this.glAccountId = trxn.GL_Account__c;
        this.glav1Id = trxn.GL_Account_Variable_1__c;
        this.glav2Id = trxn.GL_Account_Variable_2__c;
        this.glav3Id = trxn.GL_Account_Variable_3__c;
        this.glav4Id = trxn.GL_Account_Variable_4__c;
        this.timeCardVar1Id = trxn.Time_Card_Variable_1__c;
        this.timeCardVar2Id = trxn.Time_Card_Variable_2__c;
        this.productId = trxn.Product__c;
        this.projectId = trxn.Project__c;
        this.projectTaskId = trxn.Project_Task__c;
    }

    public TransactionKey(sObject sourceDocument, sObject sourceDocumentLine){
        switch on sourceDocument {
            when Billing__c b {
                Billing_Line__c bl = (Billing_Line__c) sourceDocumentLine;
                this.sourceDocumentId = AccountingSettingsHandler.isHeaderLevelPost() ? b.Id : bl.Id;
                this.periodId = b.Accounting_Period__c;
                this.glAccountId = bl.Revenue_GL_Account__c;
                setLedgerAndPeriod(b);
                setGLAVs(bl);
                setTimeCard(bl);
                setCommonFields(bl);
            }
            when Account_Payable__c ap {
                Account_Payable_Line__c apl = (Account_Payable_Line__c) sourceDocumentLine;
                this.sourceDocumentId = AccountingSettingsHandler.isHeaderLevelPost() ? ap.Id : apl.Id;
                this.glAccountId = apl.Expense_GL_Account__c;
                setLedgerAndPeriod(ap);
                setGLAVs(apl);
                setCommonFields(apl);
            }
            when Cash_Receipt__c cr {
                this.sourceDocumentId = cr.Id;
                this.glAccountId = cr.Credit_GL_Account__c;
                setLedgerAndPeriod(cr);
                setGLAVs(cr);
                setCommonFields(cr);
            }
            when Cash_Disbursement__c cd {
                this.sourceDocumentId = cd.Id;
                this.glAccountId = cd.Debit_GL_Account__c;
                setLedgerAndPeriod(cd);
                setGLAVs(cd);
                setCommonFields(cd);
            }
            when Billing_Cash_Receipt__c bcr {
                this.sourceDocumentId = bcr.Id;
                this.ledgerId = bcr.Ledger__c;
                this.periodId = bcr.Accounting_Period__c;
                this.glAccountId = bcr.Adjustment_GL_Account__c;
                this.glav1Id = bcr.Cash_Receipt__r.GL_Account_Variable_1__c;
                this.glav2Id = bcr.Cash_Receipt__r.GL_Account_Variable_2__c;
                this.glav3Id = bcr.Cash_Receipt__r.GL_Account_Variable_3__c;
                this.glav4Id = bcr.Cash_Receipt__r.GL_Account_Variable_4__c;
                this.productId = bcr.Cash_Receipt__r.Product__c;
                this.projectId = bcr.Cash_Receipt__r.Project__c;
                this.projectTaskId = bcr.Cash_Receipt__r.Project_Task__c;
            }
            when AP_Disbursement__c apd {
                this.sourceDocumentId = apd.Id;
                this.ledgerId = apd.Cash_Disbursement__r.Ledger__c;
                this.periodId = apd.Accounting_Period__c;
                this.glAccountId = apd.Cash_Disbursement__r.Debit_GL_Account__c;
                this.glav1Id = apd.Cash_Disbursement__r.GL_Account_Variable_1__c;
                this.glav2Id = apd.Cash_Disbursement__r.GL_Account_Variable_2__c;
                this.glav3Id = apd.Cash_Disbursement__r.GL_Account_Variable_3__c;
                this.glav4Id = apd.Cash_Disbursement__r.GL_Account_Variable_4__c;
                this.productId = apd.Cash_Disbursement__r.Product__c;
                this.projectId = apd.Cash_Disbursement__r.Project__c;
                this.projectTaskId = apd.Cash_Disbursement__r.Project_Task__c;
            }
            when Scheduled_Revenue_Expense__c sre {
                this.sourceDocumentId = sre.Id;
                this.glAccountId = sre.Debit_GL_Account__c != null ? sre.Debit_GL_Account__c : sre.Credit_GL_Account__c;
                setLedgerAndPeriod(sre);
                setGLAVs(sre);
                setCommonFields(sre);
            }
            when Journal_Entry_Line__c jel {
                this.sourceDocumentId = jel.Id;
                this.ledgerId = jel.Journal_Entry__r.Ledger__c;
                this.periodId = jel.Journal_Entry__r.Accounting_Period__c;
                this.glAccountId = jel.GL_Account__c;
                setGLAVs(jel);
                setTimeCard(jel);
                setCommonFields(jel);
            }
            when Time_Card_Day__c tcd {
                this.sourceDocumentId = tcd.Id;
            }
        }
    }

    private String sourceDocumentId;
    private String secondSourceDocumentId;
    private String ledgerId;
    private String periodId;
    private String glAccountId;
    private String glav1Id;
    private String glav2Id;
    private String glav3Id;
    private String glav4Id;
    private String timeCardVar1Id;
    private String timeCardVar2Id;
    private String productId;
    private String projectId;
    private String projectTaskId;

    public Boolean equals(Object obj){
        if (obj instanceof TransactionKey) {
            TransactionKey tk = (TransactionKey)obj;
            return
                    this.sourceDocumentId == tk.sourceDocumentId
                            && this.secondSourceDocumentId == tk.secondSourceDocumentId
                            && this.ledgerId == tk.ledgerId
                            && this.periodId == tk.periodId
                            && this.glAccountId == tk.glAccountId
                            && this.glav1Id == tk.glav1Id
                            && this.glav2Id == tk.glav2Id
                            && this.glav3Id == tk.glav3Id
                            && this.glav4Id == tk.glav4Id;
        }
        return false;
    }

    public static String signature(String input) {
        Blob inputBlob = Blob.valueOf(input);
        Blob hash = Crypto.generateDigest('SHA-256', inputBlob);
        return EncodingUtil.convertToHex(hash);
    }

    public String hashCode() {
        return signature(JSON.serialize(this));
    }

    private String getSourceDocumentId(Transaction__c trxn) {
        if (trxn.Billing__c != null && trxn.Billing_Cash_Receipt__c == null) {
            return trxn.Billing__c;
        }
        else if (trxn.Billing_Line__c != null && trxn.Billing_Cash_Receipt__c == null) {
            return trxn.Billing_Line__c;
        }
        else if (trxn.Account_Payable__c != null && trxn.AP_Disbursement__c == null) {
            return trxn.Account_Payable__c;
        }
        else if (trxn.Account_Payable_Line__c != null && trxn.AP_Disbursement__c == null) {
            return trxn.Account_Payable_Line__c;
        }
        else if (trxn.Time_Card_Day__c != null) {
            return trxn.Time_Card_Day__c;
        }
        else if (trxn.Journal_Entry_Line__c != null) {
            return trxn.Journal_Entry_Line__c;
        }
        else if (trxn.Scheduled_Revenue_Expense__c != null) {
            return trxn.Scheduled_Revenue_Expense__c;
        }
        else if (trxn.Cash_Disbursement__c != null) {
            return trxn.Cash_Disbursement__c;
        }
        else if (trxn.Cash_Receipt__c != null) {
            return trxn.Cash_Receipt__c;
        }
        else if (trxn.AP_Disbursement__c != null) {
            return trxn.AP_Disbursement__c;
        }
        else if (trxn.Billing_Cash_Receipt__c != null) {
            return trxn.Billing_Cash_Receipt__c;
        }
        return trxn.Id;
    }

    private String getSecondSourceDocumentId(Transaction__c trxn) {
        if (trxn.Billing_Line__c != null && trxn.Billing_Cash_Receipt__c != null) {
            return trxn.Billing_Line__c;
        }
        else if (trxn.Account_Payable_Line__c != null && trxn.AP_Disbursement__c != null) {
            return trxn.Account_Payable_Line__c;
        }
        return null;
    }

    private void setGLAVs(SObject obj) {
        this.glav1Id = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c');
        this.glav2Id = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c');
        this.glav3Id = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c');
        this.glav4Id = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c');
    }

    private void setCommonFields(SObject obj) {
        this.productId = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Product__c');
        this.projectId = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Project__c');
        this.projectTaskId = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Project_Task__c');
    }

    private void setTimeCard(SObject obj) {
        this.timeCardVar1Id = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Time_Card_Variable_1__c');
        this.timeCardVar2Id = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Time_Card_Variable_1__c');
    }

    private void setLedgerAndPeriod(SObject obj) {
        this.ledgerId = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c');
        this.periodId = (String) obj.get(GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Period__c');
    }

}
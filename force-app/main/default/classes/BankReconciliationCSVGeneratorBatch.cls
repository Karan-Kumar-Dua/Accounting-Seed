public with sharing class BankReconciliationCSVGeneratorBatch implements Database.Batchable<sObject>, Database.Stateful {

    private Bank_Reconciliation2__c bankRec;
    private String debitType;
    private String creditType;
    @TestVisible
    private String header = Label.BANK_REC_CSV_HEADER; //'Cleared,Date,Bank Transaction Date,Amount ISO Code,Amount,Ledger Amount ISO Code,Ledger Amount,Source Link,Type,Ref,Payee,Description';
    private Boolean isLedgerAmount = false;
    private List<SObject> records = new List<SObject>();
    @TestVisible
    private String body;

    public BankReconciliationCSVGeneratorBatch(Id bankRecId) {
        this.bankRec = DomainUtils.getBankReconciliationById(bankRecId);
        debitType = this.bankRec.Type__c == BankReconciliation.BANK_TYPE ? BankReconciliation.DEPOSIT_TYPE : BankReconciliation.PAYMENT_TYPE;
        creditType = this.bankRec.Type__c == BankReconciliation.BANK_TYPE ? BankReconciliation.PAYMENT_TYPE : BankReconciliation.CHARGE_TYPE;
        isLedgerAmount = checkLedgerAmountField();
        setHeader();
    }

    public Iterable<sObject> start(Database.BatchableContext context) {
        return BankReconciliation.retrieve(bankRec.Id, true, true).items;
    }

    public void execute(Database.BatchableContext context, List<sObject> scope) {
        this.records = scope;
        if (!records.isEmpty()) {
            List<String> bodyList = new List<String>();
            for(SObject obj: records) {
                bodyList.add(getRecordString(obj));
            }
            body += String.join(bodyList, '');
        }
    }


    public void finish(Database.BatchableContext context) {
        String csvName = 'Bank Reconciliation_' + System.now().format('yyyyMMdd hh:mm') + '.csv';
        BankReconciliationHelper.saveContentVersion(csvName, Blob.valueOf(body), bankRec.Id);
    }

    private Boolean checkLedgerAmountField() {
        return MultiCurrencyHandler.isMultiCurrencyEnabled
            && BankManagerHelper.needShowLedgerAmount(bankRec.Ledger__c, (String) bankRec.get('CurrencyIsoCode'));
    }

    private void setHeader() {
        if (!isLedgerAmount) {
            header = header.remove(Label.BANK_REC_CSV_HEADER_REMOVE);
        }
        body = header + '\n';
    }

    private String getRecordString(SObject obj) {
        String recordString =
            (Id) obj.get('Bank_Reconciliation__c') != NULL
                && obj.getSObjectType() != Uncleared_Bank_Reconciliation_Line__c.getSObjectType() ? 'TRUE,' : 'FALSE,';
        recordString += getDataByObjectType(obj) + '\n';

        return recordString;
    }

    @TestVisible
    private String getDataByObjectType(SObject obj) {
        String result = '';
        switch on obj {
            when Cash_Disbursement__c cd {
                result = getCashDisbursementData(cd).removeEnd(',');
            }
            when Cash_Receipt__c cr {
                result = getCashReceiptData(cr).removeEnd(',');
            }
            when Bank_Deposit__c bd {
                result = getBankDepositData(bd);
            }
            when Journal_Entry_Line__c jel {
                result = getJournalEntryLineData(jel).removeEnd(',');
            }
            when Uncleared_Bank_Reconciliation_Line__c ul {
                result = getUnclearedBankRecLineData(ul).removeEnd(',');
            }
        }
        return result;
    }

    @TestVisible
    private String getCashDisbursementData(Cash_Disbursement__c obj) {
        String ref;
        if (obj.Check_Number__c != NULL && String.isNotBlank(obj.Reference__c)) {
            ref = String.valueOf(obj.Check_Number__c) + ' - ' + obj.Reference__c;
        } else if (obj.Check_Number__c != NULL) {
            ref = String.valueOf(obj.Check_Number__c);
        } else if (String.isNotBlank(obj.Reference__c)) {
            ref = obj.Reference__c;
        } else {
            ref = '';
        }
        return wrap(obj.Disbursement_Date__c != NULL ? obj.Disbursement_Date__c.format() : '') +
            + wrap((obj.Cleared_Date__c != NULL ? obj.Cleared_Date__c.format() : '')) +
            + getAmount(obj, obj.Debit_GL_Account__c) +
            + wrap(obj.Name) +
            + wrap((obj.Debit_GL_Account__r.Bank__c == true ? BankReconciliation.TRANSFER_TYPE : creditType)) +
            + wrap(ref) +
            + wrap(obj.Payee__c) +
            + wrap(obj.Description__c);
    }

    @TestVisible
    private String getCashReceiptData(Cash_Receipt__c obj) {
        return wrap(obj.Receipt_Date__c != NULL ? obj.Receipt_Date__c.format() : '') +
            + wrap((obj.Cleared_Date__c != NULL ? obj.Cleared_Date__c.format() : '')) +
            + getAmount(obj, obj.Credit_GL_Account__c) +
            + wrap(obj.Name) +
            + wrap((obj.Credit_GL_Account__r.Bank__c == true ? BankReconciliation.TRANSFER_TYPE : debitType)) +
            + wrap(obj.Check_Number__c != NULL ? String.valueOf(obj.Check_Number__c) + ' - ' + obj.Payment_Reference__c : obj.Payment_Reference__c) +
            + wrap(obj.Account__r.Name) +
            + wrap(obj.Description__c);

    }

    private String getBankDepositData(Bank_Deposit__c obj) {
        return wrap(obj.Deposit_Date__c != NULL ? obj.Deposit_Date__c.format() : '') +
            + wrap((obj.Cleared_Date__c != NULL ? obj.Cleared_Date__c.format() : '')) +
            + getAmount(obj, NULL) +
            + wrap(obj.Name) +
            + wrap(debitType) +
            + wrap(obj.Deposit_Reference__c) +
            + ',' + '';
    }

    private String getJournalEntryLineData(Journal_Entry_Line__c obj) {
        String payee;
        if (obj.Account__c != NULL) {
            payee = obj.Account__r.Name;
        } else if (obj.Contact__c != NULL) {
            payee = obj.Contact__r.Name;
        } else if (obj.Employee__c != NULL) {
            payee = obj.Employee__r.Name;
        }
        return wrap(obj.Journal_Entry__r.Journal_Date__c != NULL ? obj.Journal_Entry__r.Journal_Date__c.format() : '') +
            + wrap((obj.Cleared_Date__c != NULL ? obj.Cleared_Date__c.format() : '')) +
            + getAmount(obj, NULL) +
            + wrap(obj.Name) +
            + wrap((obj.Debit__c != NULL ? debitType : creditType)) +
            + wrap(obj.Reference__c) +
            + wrap(payee) +
            + wrap(obj.Description__c);
    }

    private String getUnclearedBankRecLineData(Uncleared_Bank_Reconciliation_Line__c obj) {
        return wrap(obj.Date__c != NULL ? obj.Date__c.format() : '') +
            + wrap((obj.Cleared_Date__c != NULL ? obj.Cleared_Date__c.format() : '')) +
            + getAmount(obj, getUnclearedSourceGlAccountId(obj)) +
            + wrap(getUnclearedSourceName(obj)) +
            + wrap(obj.Type__c) +
            + wrap(getUnclearedRef(obj)) +
            + wrap(obj.Payee_Name__c) +
            + wrap(obj.Description__c);
    }


    @TestVisible
    private String getUnclearedRef(Uncleared_Bank_Reconciliation_Line__c obj) {
        String ref;
        if (obj.Cash_Disbursement__c != null) {
            if (obj.Cash_Disbursement__r.Check_Number__c != null && String.isNotBlank(obj.Reference__c)) {
                ref = String.valueOf(obj.Cash_Disbursement__r.Check_Number__c) + ' - ' + obj.Reference__c;
            }
            else if (obj.Cash_Disbursement__r.Check_Number__c != null && String.isBlank(obj.Reference__c)) {
                ref = String.valueOf(obj.Cash_Disbursement__r.Check_Number__c);
            }
            else {
                ref = obj.Reference__c;
            }
        } 
        else if (obj.Cash_Receipt__c != null) {
            if (obj.Cash_Receipt__r.Check_Number__c != null && String.isNotBlank(obj.Reference__c)) {
                ref = String.valueOf(obj.Cash_Receipt__r.Check_Number__c) + ' - ' + obj.Reference__c;
            }
            else if (obj.Cash_Receipt__r.Check_Number__c != null && String.isBlank(obj.Reference__c)) {
                ref = String.valueOf(obj.Cash_Receipt__r.Check_Number__c);
            }
            else {
                ref = obj.Reference__c;
            }
        }
        else {
            ref = obj.Reference__c;
        }

        return ref;
    }

    private String getUnclearedSourceName(Uncleared_Bank_Reconciliation_Line__c obj) {
        if (obj.Bank_Deposit__c != NULL) {
            return obj.Bank_Deposit__r.Name;
        }
        else if (obj.Cash_Disbursement__c != NULL) {
            return obj.Cash_Disbursement__r.Name;
        }
        else if (obj.Cash_Receipt__c != NULL) {
            return obj.Cash_Receipt__r.Name;
        }
        else if (obj.Journal_Entry_Line__c != NULL) {
            return obj.Journal_Entry_Line__r.Name;
        }
        return '';
    }

    private String getUnclearedSourceGlAccountId(Uncleared_Bank_Reconciliation_Line__c obj) {
        if (obj.Cash_Disbursement__c != NULL) {
            return obj.Cash_Disbursement__r.Debit_GL_Account__c;
        }
        else if (obj.Cash_Receipt__c != NULL) {
            return obj.Cash_Receipt__r.Credit_GL_Account__c;
        }
        return NULL;
    }

    private String getAmount(SObject obj, Id glAccountId) {
        return isLedgerAmount
            ? getAmountIsoCode(obj) + getAmountVal(obj, glAccountId) + getLedgerAmountIsoCode(obj) + getLedgerAmountVal(obj, glAccountId)
            : getAmountIsoCode(obj) + getAmountVal(obj, glAccountId);
    }

    private String getAmountVal(SObject obj, Id glAccountId) {
        return wrap(getFormattedAmountVal((setAmountByType(obj, (Decimal) obj.get('Amount__c'), glAccountId))));
    }

    private String getLedgerAmountVal(SObject obj, Id glAccountId) {
        return wrap(getFormattedAmountVal((setAmountByType(obj, (Decimal) obj.get('Ledger_Amount__c'), glAccountId))));
    }

    @TestVisible
    private String getFormattedAmountVal(Decimal amount) {
        String result = '';
        if (amount != NULL) {
            Decimal temp = amount.setScale(2);
            String fraction = String.valueOf(temp).substringAfter('.');
            result = (amount < 0 ? (Decimal.valueOf(amount.intValue()) - 0.1) : (Decimal.valueOf(amount.intValue()) + 0.1)).format();
            result = result.substring(0, result.length() - 1) + fraction;
        }
        return result;
    }

    private String getAmountIsoCode(SObject obj) {
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return wrap((String) obj.get('CurrencyIsoCode'));
        }
        else {
            return wrap(UserInfo.getDefaultCurrency());
        }
    }

    private String getLedgerAmountIsoCode(SObject obj) {
        return wrap((String) bankRec.get('CurrencyIsoCode'));
    }

    private Decimal setAmountByType(SObject obj,  Decimal amount, Id glAccountId) {
        if (bankRec.Type__c == BankReconciliation.BANK_TYPE) {
            return setNegativeSign(setNegativeBankType(obj, amount, glAccountId), amount);
        }
        else {
            return setNegativeSign(setNegativeCreditCardType(obj, amount, glAccountId), amount);
        }
    }

    private Boolean setNegativeBankType(SObject obj, Decimal amount, Id glAccountId) {
        if (amount > 0 && ((isCashOut(obj) && !isCashOutTransfer(obj, glAccountId))
            || (isUnclearedCashOut(obj) && !isUnclearedCashOutTransfer(obj, glAccountId))
            || isCashInTransfer(obj, glAccountId)
            || isUnclearedCashInTransfer(obj, glAccountId))) {
            return true;
        }
        else if (amount < 0 && ((isCashIn(obj) && !isCashInTransfer(obj, glAccountId))
            || (isUnclearedCashIn(obj) && !isUnclearedCashInTransfer(obj, glAccountId))
            || isCashOutTransfer(obj, glAccountId)
            || isUnclearedCashOutTransfer(obj, glAccountId))) {
            return true;
        }
        return false;
    }

    private Boolean setNegativeCreditCardType(SObject obj,  Decimal amount, Id glAccountId) {
        if (amount < 0 && ((isCashOut(obj) && !isCashOutTransfer(obj, glAccountId))
            || (isUnclearedCashOut(obj) && !isUnclearedCashOutTransfer(obj, glAccountId))
            || isCashInTransfer(obj, glAccountId)
            || isUnclearedCashInTransfer(obj, glAccountId))) {
            return true;
        }
        else if (amount > 0 && ((isCashIn(obj) && !isCashInTransfer(obj, glAccountId))
            || (isUnclearedCashIn(obj) && !isUnclearedCashInTransfer(obj, glAccountId))
            || isCashOutTransfer(obj, glAccountId)
            || isUnclearedCashOutTransfer(obj, glAccountId))) {
            return true;
        }
        return false;
    }

    private Decimal setNegativeSign(Boolean isNegative, Decimal amount) {
        if (isNegative) {
            return amount > 0 ? amount * -1 : amount;
        }
        else {
            return amount < 0 ? amount * -1 : amount;
        }
    }

    private Boolean isCashIn(SObject obj) {
        return isEqualSobj(obj, Cash_Receipt__c.SObjectType)
            || isEqualSobj(obj, Bank_Deposit__c.SObjectType)
            ||(isEqualSobj(obj, Journal_Entry_Line__c.SObjectType) && obj.get(Journal_Entry_Line__c.Debit__c) != NULL);
    }

    private Boolean isCashOut(SObject obj) {
        return isEqualSobj(obj, Cash_Disbursement__c.SObjectType)
            || (isEqualSobj(obj, Journal_Entry_Line__c.SObjectType) && obj.get(Journal_Entry_Line__c.Credit__c) != NULL);
    }

    private Boolean isCashInTransfer(SObject obj, Id glAccountId) {
        return isEqualSobj(obj, Cash_Receipt__c.SObjectType)
            && ((Cash_Receipt__c) obj).Credit_GL_Account__r.Bank__c
            && glAccountId != NULL && ((Cash_Receipt__c) obj).Credit_GL_Account__c == glAccountId;
    }

    private Boolean isCashOutTransfer(SObject obj, Id glAccountId) {
        return isEqualSobj(obj, Cash_Disbursement__c.SObjectType)
            && ((Cash_Disbursement__c) obj).Debit_GL_Account__r.Bank__c
            && glAccountId != NULL && ((Cash_Disbursement__c) obj).Debit_GL_Account__c == glAccountId;
    }

    private Boolean isUnclearedCashOut(SObject obj) {
        return isEqualSobj(obj, Uncleared_Bank_Reconciliation_Line__c.SObjectType)
            && (((Uncleared_Bank_Reconciliation_Line__c) obj).Cash_Disbursement__c != null
            || (((Uncleared_Bank_Reconciliation_Line__c) obj).Journal_Entry_Line__c != null
            && ((Uncleared_Bank_Reconciliation_Line__c) obj).Journal_Entry_Line__r.Credit__c != null)
        );
    }

    private Boolean isUnclearedCashIn(SObject obj) {
        return isEqualSobj(obj, Uncleared_Bank_Reconciliation_Line__c.SObjectType)
            && (((Uncleared_Bank_Reconciliation_Line__c) obj).Cash_Receipt__c != null
                || ((Uncleared_Bank_Reconciliation_Line__c) obj).Bank_Deposit__c != null
                || (((Uncleared_Bank_Reconciliation_Line__c) obj).Journal_Entry_Line__c != null
                    && ((Uncleared_Bank_Reconciliation_Line__c) obj).Journal_Entry_Line__r.Debit__c != null)
        );
    }

    private Boolean isUnclearedCashOutTransfer(SObject obj, Id glAccountId) {
        return compareUnclearedLineTypeTransfer(obj)
            && ((Uncleared_Bank_Reconciliation_Line__c) obj).Cash_Disbursement__c != NULL
            && glAccountId != NULL && bankRec.Bank_Account__c == glAccountId;
    }

    private Boolean isUnclearedCashInTransfer(SObject obj, Id glAccountId) {
        return compareUnclearedLineTypeTransfer(obj)
            && ((Uncleared_Bank_Reconciliation_Line__c) obj).Cash_Receipt__c != NULL
            && glAccountId != NULL && bankRec.Bank_Account__c == glAccountId;
    }

    private Boolean compareUnclearedLineTypeTransfer(SObject obj) {
        return isEqualSobj(obj, Uncleared_Bank_Reconciliation_Line__c.SObjectType)
            && obj.get(Uncleared_Bank_Reconciliation_Line__c.Type__c) == 'Transfer';
    }

    private String wrap(Object val) {
        String res = String.valueOf(val == NULL ? '' : val).escapeCsv();
        return res + ',';
    }

    private Boolean isEqualSobj(Sobject obj, SObjectType sobjType) {
        return obj.getSObjectType() == sobjType;
    }

}
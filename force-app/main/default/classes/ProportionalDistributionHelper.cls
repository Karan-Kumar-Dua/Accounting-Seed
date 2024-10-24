public with sharing class ProportionalDistributionHelper {

    private Boolean isLlpMode = AccountingSettingsHandler.isLineLevelPost();
    private Map<Id, TransactionAmountCalculation> transactionAmountWrappersByIds = new Map<Id, TransactionAmountCalculation>();
    private Schema.SObjectType sourceSObjectType;
    private Map<Id, Tax_Group__c> taxGroupMap = new Map<Id, Tax_Group__c>();
    private Map<Schema.SObjectType, List<Schema.SObjectField>> childToParent = new Map<Schema.SObjectType, List<Schema.SObjectField>>{
        Billing_Line__c.getSObjectType() => new List<Schema.SObjectField> {
            Billing_Line__c.Billing__c,
            Billing_Line__c.Revenue_GL_Account__c,
            Billing_Line__c.Tax_Amount2__c
        },
        Account_Payable_Line__c.getSObjectType() => new List<Schema.SObjectField> {
            Account_Payable_Line__c.Account_Payable__c,
            Account_Payable_Line__c.Expense_GL_Account__c,
            Account_Payable_Line__c.Tax_Amount__c
        }
    };
    private Map<Schema.SObjectType, Schema.SObjectField> childToRelated = new Map<Schema.SObjectType, Schema.SObjectField>{
        Billing_Line__c.getSObjectType() => Billing_Cash_Receipt__c.Billing__c,
        Account_Payable_Line__c.getSObjectType() => AP_Disbursement__c.Account_Payable__c
    };
    private List<SObject> sobjectsLines;

    public ProportionalDistributionHelper(List<SObject> sobjects, List<SObject> sobjectsLines) {
        this.sobjectsLines = sobjectsLines;
        if (!sobjectsLines.isEmpty()) {
            this.sourceSObjectType = sobjectsLines[0].getSObjectType();
        }
        init(sobjects);
    }

    public ProportionalDistributionHelper(List<SObject> sobjects) {
        if (!sobjects.isEmpty()) {
            setSourceSObjectType(sobjects[0]);
        }
        init(sobjects);
    }

    public TransactionAmountCalculation getTransactionAmountCalculationById(Id sourceId) {
        if (transactionAmountWrappersByIds.containsKey(sourceId)) {
            return transactionAmountWrappersByIds.get(sourceId);
        }
        return null;
    }

    public Integer totalLinesCount() {
        Integer count = 0;
        for (TransactionAmountCalculation calc : transactionAmountWrappersByIds.values()) {
            count += calc.lines.size();
        }
        return count;
    }

    private void init(List<SObject> sobjects) {
        Map<Id, SObject> sobjectIds = new Map<Id, SObject>();
        Map<Id, SObject> creditMemoIds = new Map<Id, SObject>();
        Map<Id, SObject> creditMemoByInvoice = new Map<Id, SObject>();
        Map<Id, List<Sobject>> payByInvoice = new Map<Id, List<Sobject>>();
        for (SObject obj : sobjects) {
            sobjectIds.put((Id) obj.get(childToRelated.get(sourceSObjectType)), obj);
            if (isCreditMemoAmount(obj)) {
                creditMemoIds.put((Id) obj.get(childToRelated.get(sourceSObjectType)), obj);
            }
        }
        setPayByInvoiceMap(sobjectIds, payByInvoice);

        if (!creditMemoIds.isEmpty()) {
            setCreditMemoMap(sobjectIds, creditMemoByInvoice, creditMemoIds);
        }

        if (sobjectsLines == null) {
            setFullTransactionAmountCalculation(sobjectIds, creditMemoByInvoice, payByInvoice);
        } else {
            setTransactionAmountCalculationByLines(sobjectIds, creditMemoByInvoice, payByInvoice);
        }

        taxGroupMap = new Map<Id, Tax_Group__c>(DomainUtils.getTaxGroupWithTaxRatesByIds(taxGroupMap.keySet()));

        for (TransactionAmountCalculation tc : transactionAmountWrappersByIds.values()) {
            tc.calculate(taxGroupMap);
        }
    }

    private void setTransactionAmountCalculationByLines(Map<Id, SObject> sobjectIds,
                                                        Map<Id, SObject> creditMemoByInvoice,
                                                        Map<Id, List<Sobject>> payByInvoice) {

        Map<String, TransactionAmountCalculationLine> aggregateLinesByKey = new Map<String,TransactionAmountCalculationLine>();
        List<SObject> allLines = new List<SObject>();
        if (!creditMemoByInvoice.isEmpty()) {
            allLines = getCreditMemoLines(creditMemoByInvoice.keySet());
        }
        allLines.addAll(sobjectsLines);

        for (SObject line : allLines) {
            if (sobjectIds.containsKey((String) line.get(childToParent.get(sourceSObjectType)[0]))
                || creditMemoByInvoice.containsKey((String) line.get(childToParent.get(sourceSObjectType)[0]))) {
                String tk = getLineKey(line);

                TransactionAmountCalculationLine aggregatedLine;
                if (aggregateLinesByKey.containsKey(tk)) {
                    aggregatedLine = aggregateLinesByKey.get(tk);
                    aggregatedLine.subTotal += (Decimal) line.get('Sub_Total__c');
                    aggregatedLine.taxAmount += (Decimal) line.get(childToParent.get(sourceSObjectType)[2]);
                } else {
                    aggregatedLine = new TransactionAmountCalculationLine();
                    if (AccountingSettingsHandler.isLineLevelPost()) {
                        aggregatedLine.recordId = (String) line.Id;
                    }
                    aggregatedLine.sourceId = (String) line.get(childToParent.get(sourceSObjectType)[0]);
                    aggregatedLine.glAccountId = (String) line.get(childToParent.get(sourceSObjectType)[1]);
                    aggregatedLine.glav1Id = (String) line.get('GL_Account_Variable_1__c');
                    aggregatedLine.glav2Id = (String) line.get('GL_Account_Variable_2__c');
                    aggregatedLine.glav3Id = (String) line.get('GL_Account_Variable_3__c');
                    aggregatedLine.glav4Id = (String) line.get('GL_Account_Variable_4__c');
                    if (sourceSObjectType == Billing_Line__c.getSObjectType()) {
                        aggregatedLine.timeCardVar1Id = (String) line.get('Time_Card_Variable_1__c');
                        aggregatedLine.timeCardVar2Id = (String) line.get('Time_Card_Variable_2__c');
                    }
                    aggregatedLine.projectId = (String) line.get('Project__c');
                    aggregatedLine.projectTaskId = (String) line.get('Project_Task__c');
                    aggregatedLine.productId = (String) line.get('Product__c');
                    aggregatedLine.taxGroupId = (String) line.get('Tax_Group__c');
                    aggregatedLine.subTotal = (Decimal) line.get('Sub_Total__c');
                    aggregatedLine.taxAmount = (Decimal) line.get(childToParent.get(sourceSObjectType)[2]);

                    aggregateLinesByKey.put(tk, aggregatedLine);
                }
            }
        }

        for (TransactionAmountCalculationLine calcLine : aggregateLinesByKey.values()) {
            Boolean isCreditMemoLine = false;
            String sourceId = calcLine.sourceId;
            if (creditMemoByInvoice.keySet().contains(sourceId)) {
                sourceId = sourceSObjectType == Billing_Line__c.getSObjectType()
                    ? ((Billing_Credit_Memo__c) creditMemoByInvoice.get(sourceId)).Billing_Invoice__c
                    : ((AP_Credit_Memo__c) creditMemoByInvoice.get(sourceId)).Account_Payable_Invoice__c;
                isCreditMemoLine = true;
            }

            taxGroupMap.put(calcLine.taxGroupId, null);
            TransactionAmountCalculationLine transCalcLine = new TransactionAmountCalculationLine(calcLine, isCreditMemoLine);
            if (transactionAmountWrappersByIds.containsKey(sourceId)) {
                transactionAmountWrappersByIds.get(sourceId).lines.add(transCalcLine);
                if (isCreditMemoLine
                    && creditMemoByInvoice.containsKey(calcLine.sourceId)
                    && !transactionAmountWrappersByIds.get(sourceId).creditMemoMap.keySet().contains(creditMemoByInvoice.get(calcLine.sourceId).Id)) {
                    transactionAmountWrappersByIds.get(sourceId).creditMemoMap.put(
                        creditMemoByInvoice.get(calcLine.sourceId).Id,
                        creditMemoByInvoice.get(calcLine.sourceId)
                    );
                }
                if (payByInvoice.containsKey(sourceId) && transactionAmountWrappersByIds.get(sourceId).existedPay.isEmpty()) {
                    transactionAmountWrappersByIds.get(sourceId).existedPay.addAll(payByInvoice.get(sourceId));
                }
            } else {
                TransactionAmountCalculation tc = new TransactionAmountCalculation(sobjectIds.get(sourceId));
                tc.externalTotal = (Decimal) sobjectIds.get(sourceId).getSObject(
                    sourceSObjectType == Billing_Line__c.getSObjectType() ? 'Billing__r' : 'Account_Payable__r'
                ).get('Total__c');
                tc.lines.add(transCalcLine);
                if (isCreditMemoLine
                    && creditMemoByInvoice.containsKey(calcLine.sourceId)
                    && !tc.creditMemoMap.keySet().contains(creditMemoByInvoice.get(calcLine.sourceId).Id)) {
                    tc.creditMemoMap.put(creditMemoByInvoice.get(calcLine.sourceId).Id, creditMemoByInvoice.get(calcLine.sourceId));
                }
                if (payByInvoice.containsKey(sourceId) && tc.existedPay.isEmpty()) {
                    tc.existedPay.addAll(payByInvoice.get(sourceId));
                }
                transactionAmountWrappersByIds.put(sourceId, tc);
            }
        }
    }

    private void setFullTransactionAmountCalculation(Map<Id, SObject> sobjectIds,
                                                        Map<Id, SObject> creditMemoByInvoice,
                                                        Map<Id, List<Sobject>> payByInvoice) {
        for (AggregateResult res : getLinesByTransactionKey(sobjectIds.keySet())) {
            Boolean isCreditMemoLine = false;
            String sourceId = (String) res.get('sourceId');
            if (creditMemoByInvoice.keySet().contains(sourceId)) {
                sourceId = sourceSObjectType == Billing_Line__c.getSObjectType()
                    ? ((Billing_Credit_Memo__c) creditMemoByInvoice.get(sourceId)).Billing_Invoice__c
                    : ((AP_Credit_Memo__c) creditMemoByInvoice.get(sourceId)).Account_Payable_Invoice__c;
                isCreditMemoLine = true;
            }
            taxGroupMap.put((String) res.get('taxGroupId'), null);
            TransactionAmountCalculationLine calcLine = new TransactionAmountCalculationLine(res, isCreditMemoLine);
            if (transactionAmountWrappersByIds.containsKey(sourceId)) {
                transactionAmountWrappersByIds.get(sourceId).lines.add(calcLine);
                if (isCreditMemoLine && !transactionAmountWrappersByIds.get(sourceId).creditMemoMap.keySet().contains(creditMemoByInvoice.get((String) res.get('sourceId')).Id)) {
                    transactionAmountWrappersByIds.get(sourceId).creditMemoMap.put(
                        creditMemoByInvoice.get((String) res.get('sourceId')).Id,
                        creditMemoByInvoice.get((String) res.get('sourceId'))
                    );
                }
                if (payByInvoice.containsKey(sourceId) && transactionAmountWrappersByIds.get(sourceId).existedPay.isEmpty()) {
                    transactionAmountWrappersByIds.get(sourceId).existedPay.addAll(payByInvoice.get(sourceId));
                }
            } else {
                TransactionAmountCalculation tc = new TransactionAmountCalculation(sobjectIds.get(sourceId));
                tc.lines.add(calcLine);
                if (isCreditMemoLine && !tc.creditMemoMap.keySet().contains(creditMemoByInvoice.get((String) res.get('sourceId')).Id)) {
                    tc.creditMemoMap.put(creditMemoByInvoice.get((String) res.get('sourceId')).Id, creditMemoByInvoice.get((String) res.get('sourceId')));
                }
                if (payByInvoice.containsKey(sourceId) && tc.existedPay.isEmpty()) {
                    tc.existedPay.addAll(payByInvoice.get(sourceId));
                }
                transactionAmountWrappersByIds.put(sourceId, tc);
            }
        }
    }

    private void setPayByInvoiceMap(Map<Id, SObject> sobjectIds, Map<Id, List<Sobject>> payByInvoice) {
        if (!sobjectIds.isEmpty() && sobjectIds.values()[0].getSObjectType() == Billing_Cash_Receipt__c.getSObjectType()) {
            for (Billing_Cash_Receipt__c bcr : DomainUtils.getBillingCashReceiptsByBillingId(sobjectIds.keySet())) {
                if (payByInvoice.keySet().contains(bcr.Billing__c)) {
                    payByInvoice.get(bcr.Billing__c).add(bcr);
                } else {
                    payByInvoice.put(bcr.Billing__c, new List<Sobject> {bcr});
                }
            }
        } else {
            for (AP_Disbursement__c apd : DomainUtils.getAPDisbursementByPayableId(sobjectIds.keySet())) {
                if (payByInvoice.keySet().contains(apd.Account_Payable__c)) {
                    payByInvoice.get(apd.Account_Payable__c).add(apd);
                } else {
                    payByInvoice.put(apd.Account_Payable__c, new List<Sobject> {apd});
                }
            }
        }
    }

    private void setCreditMemoMap(Map<Id, SObject> sobjectIds, Map<Id, SObject> creditMemoByInvoice, Map<Id, SObject> creditMemoIds) {
        if (!sobjectIds.isEmpty() && sobjectIds.values()[0].getSObjectType() == Billing_Cash_Receipt__c.getSObjectType()) {
            for (Billing_Credit_Memo__c bcm : DomainUtils.getBillingCreditMemosByInvoiceId(creditMemoIds.keySet())) {
                sobjectIds.put(bcm.Billing_Credit_Memo__c, creditMemoIds.get(bcm.Billing_Invoice__c));
                creditMemoByInvoice.put(bcm.Billing_Credit_Memo__c, bcm);
            }
        } else {
            for (AP_Credit_Memo__c apcm : DomainUtils.getApCreditMemosByInvoiceId(creditMemoIds.keySet())) {
                sobjectIds.put(apcm.Account_Payable_Credit_Memo__c, creditMemoIds.get(apcm.Account_Payable_Invoice__c));
                creditMemoByInvoice.put(apcm.Account_Payable_Credit_Memo__c, apcm);
            }
        }
    }

    private List<Sobject> getCreditMemoLines(Set<Id> creditMemoIds) {
        if (!creditMemoIds.isEmpty() && new List<Id> (creditMemoIds)[0].getSObjectType() == Billing__c.getSObjectType()) {
            return DomainUtils.getBillingLinesByMasterId(creditMemoIds).values();
        } else {
            return DomainUtils.getAccountPayableLinesByMasterId(creditMemoIds).values();
        }
    }

    private Boolean isCreditMemoAmount(SObject obj) {
        return obj.getSobjectType() == Billing_Cash_Receipt__c.getSObjectType()
        ? ((Billing_Cash_Receipt__c) obj).Billing__r.Credit_Memo_Applied_Amount__c != 0
        : ((AP_Disbursement__c) obj).Account_Payable__r.Credit_Memo_Applied_Amount__c != 0;
    }

    private void setSourceSObjectType(SObject obj) {
        this.sourceSObjectType = obj.getSobjectType() == Billing_Cash_Receipt__c.getSObjectType()
            ? Billing_Line__c.getSObjectType() : Account_Payable_Line__c.getSObjectType() ;
    }

    private List<AggregateResult> getLinesByTransactionKey(Set<Id> sobjectIds) {
        String queryString = 'SELECT' + (isLlpMode ? ' Id recordId,' : '')
            + ' SUM(Sub_Total__c) subTotal, '
            + ' SUM(' + childToParent.get(sourceSObjectType)[2] + ') taxAmount, '
            + childToParent.get(sourceSObjectType)[0] + ' sourceId, '
            + childToParent.get(sourceSObjectType)[1] + ' glAccountId, '
            + 'GL_Account_Variable_1__c glav1Id,  GL_Account_Variable_2__c glav2Id, GL_Account_Variable_3__c glav3Id, GL_Account_Variable_4__c glav4Id, '
            + (this.sourceSObjectType == Billing_Line__c.getSObjectType() ? 'Time_Card_Variable_1__c timeCardVar1Id,  Time_Card_Variable_2__c timeCardVar2Id, ' : '')
            + 'Project__c projectId,  Project_Task__c projectTaskId, Product__c productId, Tax_Group__c taxGroupId '
            + 'FROM ' + this.sourceSObjectType + ' WHERE ' + childToParent.get(sourceSObjectType)[0] + ' IN :sobjectIds '
            + ' GROUP BY ' + (isLlpMode ? 'Id,' : '')
            + childToParent.get(sourceSObjectType)[0] + ', ' + childToParent.get(sourceSObjectType)[1]
            + ', GL_Account_Variable_1__c,  GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c, '
            + (this.sourceSObjectType == Billing_Line__c.getSObjectType() ? 'Time_Card_Variable_1__c,  Time_Card_Variable_2__c, ' : '')
            + 'Project__c,  Project_Task__c, Product__c, Tax_Group__c LIMIT 2000';

        return (List<AggregateResult>) Database.query(queryString);
    }

    private String getLineKey(SObject line) {
        String key = '';
        if (line.getSObjectType() == Billing_Line__c.getSObjectType()) {
            key += String.valueOf(line.get('Time_Card_Variable_1__c')) +
                String.valueOf(line.get('Time_Card_Variable_2__c'));
        }

        key += String.valueOf(line.get(childToParent.get(sourceSObjectType)[0])) +
            String.valueOf(line.get(childToParent.get(sourceSObjectType)[1])) +
            String.valueOf(line.get('GL_Account_Variable_1__c')) +
            String.valueOf(line.get('GL_Account_Variable_2__c')) +
            String.valueOf(line.get('GL_Account_Variable_3__c')) +
            String.valueOf(line.get('GL_Account_Variable_4__c')) +
            String.valueOf(line.get('Project__c')) +
            String.valueOf(line.get('Project_Task__c')) +
            String.valueOf(line.get('Product__c')) +
            String.valueOf(line.get('Tax_Group__c'));

        if (AccountingSettingsHandler.isLineLevelPost()) {
            key += String.valueOf(line.Id);
        }

        return key;
    }

    public with sharing class TransactionAmountCalculation {
        public Map<Id, Sobject> creditMemoMap = new Map<Id, Sobject>();
        public List<Sobject> existedPay = new List<Sobject>();
        private Decimal balance = 0;
        private Decimal subTotal = 0;
        @TestVisible
        private Decimal total = 0;
        private Decimal taxAmount = 0;
        public Decimal adjustmentAmount = 0;
        public List<TransactionAmountCalculationLine> lines = new List<TransactionAmountCalculationLine>();
        private SObject masterObject;
        public Decimal externalTotal;

        public TransactionAmountCalculation(SObject obj) {
            this.masterObject = obj;
        }

        private void getTotal() {
            if (!creditMemoMap.isEmpty()) {
                for (Sobject cm : creditMemoMap.values()) {
                    if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                        (Id) cm.get('Accounting_Period__c'),
                        (Id) masterObject.get('Accounting_Period__c')) == 1) {
                        total += masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType()
                            ? ((AP_Credit_Memo__c) cm).Account_Payable_Credit_Memo__r.Total__c * -1
                            : ((Billing_Credit_Memo__c) cm).Billing_Credit_Memo__r.Total__c * -1;
                    }
                }
            }
        }

        private void getAdjustmentAmount() {
            if (masterObject.getSObjectType() == Billing_Cash_Receipt__c.getSObjectType()
                && (Decimal) masterObject.get(Billing_Cash_Receipt__c.Adjustment_Amount__c) != null
                && (Decimal) masterObject.get(Billing_Cash_Receipt__c.Adjustment_Amount__c) != 0) {
                adjustmentAmount = (Decimal) masterObject.get(Billing_Cash_Receipt__c.Adjustment_Amount__c);
                balance += adjustmentAmount;
            }
        }

        private void getDiscountAmount() {
            if (masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType()
                && (Decimal) masterObject.get(AP_Disbursement__c.Discount_Amount__c) != null
                && (Decimal) masterObject.get(AP_Disbursement__c.Discount_Amount__c) != 0) {
                balance += (Decimal) masterObject.get(AP_Disbursement__c.Discount_Amount__c);
            }
        }

        private Boolean isPayStatusPosted(Sobject pay) {
            return (String) pay.get(
                masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType() ?
                    AP_Disbursement__c.Status__c : Billing_Cash_Receipt__c.Status__c
            ) == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
        }

        private Boolean isValidPaymentStatus(Sobject pay) {
            if (masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType()) {
                return !(((AP_Disbursement__c) pay).Cash_Disbursement__r.Payment_Status__c == CashDisbursementActions.STATUS_VOID);
            } else if (masterObject.getSObjectType() == Billing_Cash_Receipt__c.getSObjectType()) {
                return !((Billing_Cash_Receipt__c) pay).Cash_Receipt__r.Void__c;
            }
            return true;
        }

        private void setMasterPayBalance() {
            balance = (Decimal) masterObject.get(
                masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType() ? 'Paid_Amount__c' : 'Applied_Amount__c'
            );
        }

        public void calculate(Map<Id, Tax_Group__c> tgMap) {
            List<Sobject> tempExistedPay = new List<SObject>();
            setMasterPayBalance();
            Sobject masterPayWithTransaction;
            if (!existedPay.isEmpty()) {
                for (Sobject pay : existedPay) {
                    if (pay.Id != masterObject.Id && isValidPaymentStatus(pay) &&
                        ((AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                        (Id) pay.get('Accounting_Period__c'),
                        (Id) masterObject.get('Accounting_Period__c')) == -1)
                        || (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                        (Id) pay.get('Accounting_Period__c'),
                        (Id) masterObject.get('Accounting_Period__c')) == 0 && isPayStatusPosted(pay)))) {
                        balance += (Decimal) pay.get(
                            masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType() ? 'Paid_Amount__c' : 'Applied_Amount__c'
                        );
                        tempExistedPay.add(pay);
                    }
                    if (pay.Id == masterObject.Id) {
                        masterPayWithTransaction = pay;
                    }

                    if (pay.Id != masterObject.Id 
                            && pay.getSObjectType() == Billing_Cash_Receipt__c.getSObjectType() 
                            && isValidPaymentStatus(pay)
                            && (Decimal) pay.get(Billing_Cash_Receipt__c.Adjustment_Amount__c) != null
                            && (Decimal) pay.get(Billing_Cash_Receipt__c.Adjustment_Amount__c) != 0) {
                        balance += (Decimal) pay.get(Billing_Cash_Receipt__c.Adjustment_Amount__c);
                    }
                }
            }
            existedPay = tempExistedPay;
            if (masterPayWithTransaction != null) {
                existedPay.add(masterPayWithTransaction);
            }

            for (TransactionAmountCalculationLine line : lines) {
                if (!creditMemoMap.isEmpty() && line.isCreditMemo) {
                    for (Sobject cm : creditMemoMap.values()) {
                        if (externalTotal != null
                            && line.sourceId == (Id) cm.get(masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType()
                            ? 'Account_Payable_Credit_Memo__c' : 'Billing_Credit_Memo__c')) {
                            externalTotal += line.total;
                        }
                        if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                            (Id) cm.get('Accounting_Period__c'),
                            (Id) masterObject.get('Accounting_Period__c')) == 1
                        && line.sourceId == (Id) cm.get(masterObject.getSObjectType() == AP_Disbursement__c.getSObjectType()
                            ? 'Account_Payable_Credit_Memo__c' : 'Billing_Credit_Memo__c')) {
                            line.isFuturePeriod = true;
                            continue;
                        }
                    }
                }
                subTotal += line.subTotal;
                taxAmount += line.taxAmount;
                if (String.isNotBlank(line.taxGroupId) && tgMap.containsKey(line.taxGroupId)) {
                    line.taxRate = tgMap.get(line.taxGroupId).Combined_Tax_Rate__c;
                    line.rates = tgMap.get(line.taxGroupId).Tax_Rates__r;
                }
            }
            total = externalTotal != null ? externalTotal : (subTotal + taxAmount);
            getTotal();
            getAdjustmentAmount();
            getDiscountAmount();
            for (TransactionAmountCalculationLine line : lines) {
                line.total = total != 0 ? line.total * balance / total : line.total;
                line.subTotal = (1 + line.taxRate / 100) != 0 ? line.total / (1 + line.taxRate / 100) : line.total;
                line.subTotal = line.subTotal.setScale(2, RoundingMode.HALF_UP);
                line.taxAmount = line.total - line.subTotal;
            }
        }
    }

    public with sharing class TransactionAmountCalculationLine {
        public Boolean isFuturePeriod = false;
        public Boolean isCreditMemo;
        public String recordId;
        public String sourceId;
        public String glAccountId;
        public String glav1Id;
        public String glav2Id;
        public String glav3Id;
        public String glav4Id;
        public String timeCardVar1Id;
        public String timeCardVar2Id;
        public String productId;
        public String projectId;
        public String projectTaskId;
        public String taxGroupId;
        public Decimal subTotal = 0;
        public Decimal taxAmount = 0;
        public Decimal taxRate = 0;
        public Decimal total = 0;
        public List<Tax_Rate__c> rates = new List<Tax_Rate__c>();

        public TransactionAmountCalculationLine() {}

        public TransactionAmountCalculationLine(AggregateResult commonLine, Boolean isCreditMemo) {
            if (AccountingSettingsHandler.isLineLevelPost()) {
                this.recordId = (String) commonLine.get('recordId');
            }
            this.sourceId = (String) commonLine.get('sourceId');
            this.glAccountId = (String) commonLine.get('glAccountId');
            this.glav1Id = (String) commonLine.get('glav1Id');
            this.glav2Id = (String) commonLine.get('glav2Id');
            this.glav3Id = (String) commonLine.get('glav3Id');
            this.glav4Id = (String) commonLine.get('glav4Id');
            if (((Id) this.sourceId).getSObjectType() == Billing__c.getSObjectType()) {
                this.timeCardVar1Id = (String) commonLine.get('timeCardVar1Id');
                this.timeCardVar2Id = (String) commonLine.get('timeCardVar2Id');
            }
            this.productId = (String) commonLine.get('productId');
            this.projectId = (String) commonLine.get('projectId');
            this.projectTaskId = (String) commonLine.get('projectTaskId');
            this.taxGroupId = (String) commonLine.get('taxGroupId');
            this.subTotal = (Decimal) commonLine.get('subTotal') != null ? (Decimal) commonLine.get('subTotal') : 0;
            this.taxAmount = (Decimal) commonLine.get('taxAmount') != null ? (Decimal) commonLine.get('taxAmount') : 0;
            this.isCreditMemo = isCreditMemo;
            this.total = this.subTotal + this.taxAmount;
            setLineTaxRate();
        }

        public TransactionAmountCalculationLine(TransactionAmountCalculationLine commonLine, Boolean isCreditMemo) {
            if (AccountingSettingsHandler.isLineLevelPost()) {
                this.recordId = commonLine.recordId;
            }
            this.sourceId = commonLine.sourceId;
            this.glAccountId = commonLine.glAccountId;
            this.glav1Id = commonLine.glav1Id;
            this.glav2Id = commonLine.glav2Id;
            this.glav3Id = commonLine.glav3Id;
            this.glav4Id = commonLine.glav4Id;
            this.timeCardVar1Id = commonLine.timeCardVar1Id;
            this.timeCardVar2Id = commonLine.timeCardVar2Id;
            this.productId = commonLine.productId;
            this.projectId = commonLine.projectId;
            this.projectTaskId = commonLine.projectTaskId;
            this.taxGroupId = commonLine.taxGroupId;
            this.subTotal = commonLine.subTotal;
            this.taxAmount = commonLine.taxAmount;
            this.isCreditMemo = isCreditMemo;
            this.total = this.subTotal + this.taxAmount;
            setLineTaxRate();
        }

        private void setLineTaxRate() {
            if (taxGroupId == null && taxAmount != null && taxAmount != 0 && subTotal != null && subTotal != 0) {
                taxRate = (taxAmount / subTotal) * 100;
            }
        }
    }
}
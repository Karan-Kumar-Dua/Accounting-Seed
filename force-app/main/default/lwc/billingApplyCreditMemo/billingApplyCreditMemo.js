import {api, track} from 'lwc';
import {
    DateUtils,
    NavigationService,
    SortStrategyFactory,
    NotificationService,
    CommonUtils,
    ErrorUtils,
    LabelService
} from "c/utils";
import BillingStore from './billingStore';
import CURRENCY from '@salesforce/i18n/currency';
import LANG from '@salesforce/i18n/lang';
import getCombinedInfo from '@salesforce/apex/BillingApplyCreditMemoHelper.getCombinedInfo';
import getInvoices from '@salesforce/apex/BillingApplyCreditMemoHelper.getApplicableInvoices';
import save from '@salesforce/apex/BillingApplyCreditMemoHelper.save';
import Labels from './labels';

const INCORRECT_BILLING_TYPE = Labels.ERR_INCORRECT_BILLING_TYPE_INVOICE;
const OVERAPPLIED_INVOICE = LabelService.errorBillingBalanceNotLessThanZero;
const OVERAPPLIED_CREDIT = LabelService.errorCreditMemoBalanceLessThanZero;
const APPLIED_AMOUNT_LESS_THAN_ZERO = LabelService.errorAppliedAmountLessThanZero;
const VALUE_REQUIRED = LabelService.commonValueReq;
const MAX_INVOICES_LOADED = 2001;
const KEY_FIELD = 'billingId';

const FIXED_COLUMNS = {
    GROUP_ONE: [
        {   
            label: LabelService.customer, 
            fieldName: 'customerURL', 
            type: 'url', 
            sortable: true, 
            initialWidth: 150,
            typeAttributes: { label: {fieldName: 'customerName'}, target: self }, 
            cellAttributes: { alignment: 'left' }
        },{
            label: LabelService.commonBillingNo,
            fieldName: 'invoiceUrl',
            type: 'url',
            sortable: true,
            typeAttributes: { label: {fieldName: 'derivedName'}, target: self },
            cellAttributes: { alignment: 'left' }
        }
    ],
    GROUP_TWO: [
        { 
            label: LabelService.commonBillingAmount, 
            fieldName: 'total', 
            type: 'customCurrency', 
            sortable: true, 
            typeAttributes: { 
                currencyCode: { fieldName: 'currency' },
                isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}
        },{ 
            label: LabelService.commonTotalApplied, 
            fieldName: 'applied', 
            type: 'customCurrency', 
            sortable: true, 
            typeAttributes: { 
                currencyCode: { fieldName: 'currency' },
                isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}
        },{ 
            label: LabelService.commonBillingBalance, 
            fieldName: 'balance', 
            type: 'customCurrency', 
            sortable: true, 
            typeAttributes: { 
                currencyCode: { fieldName: 'currency' },
                isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}
        },{ 
            label: '', type: 'button-icon', initialWidth: 20,
            typeAttributes: { 
                name: 'apply', 
                title: 'Apply', 
                initialWidth: 20,
                iconName: { fieldName: 'applyIcon' },
                disabled: { fieldName: 'isClosed' }}
        },{ 
            label: LabelService.commonAppliedAmount, 
            fieldName: 'variableCredit', 
            type: 'customCurrency',
            typeAttributes: {
                currencyCode: { fieldName: 'currency' }, 
                disabled: { fieldName: 'isClosed' }, 
                rowId: { fieldName: 'billingId' },
                colId: 'variableCredit',
                errors: { fieldName: 'errors' },
                editMode: { fieldName: 'editable' }}
        },{ 
            label: LabelService.commonAppliedDate, 
            fieldName: 'appliedDate', 
            type: 'customDate', 
            initialWidth: 150,
            typeAttributes: {
                disabled: { fieldName: 'isClosed' },
                rowId: { fieldName: 'billingId' },
                colId: 'appliedDate',
                errors: { fieldName: 'errors' },
                editMode: { fieldName: 'editable' }}
        }
    ]
} 

export default class BillingApplyCreditMemo extends NavigationService {
    labels = {...LabelService, ...Labels};
    keyField = KEY_FIELD;
    billingStore = new BillingStore();
    sortFactory;

    @api 
    set recordId(val) {
        if (val) {
            this._recordId = val;
            this.init();
        }
    }
    get recordId() {
        return this._recordId;
    }

    @track isError = false;
    @track error;
    @track isSpinner = true;
    @track invoices;
    @track extraColumns;
    @track columns = [];
    @track name = '';
    @track total = 0;
    @track applied = 0;
    @track displayData = [];
    @track currencyCode = CURRENCY;
    @track isMultiCurrencyEnabled = false;
    @track creditMemo;
    @track showPopup = false;
    @track customerName;
    @track filter = {
        postingStatus: "Posted",
        customerId: undefined,
        billingNumber: undefined,
        billingDateStart: undefined,
        billingDateEnd: undefined,
        dueDateStart: undefined,
        dueDateEnd: undefined,
        billingAmountStart: undefined,
        billingAmountEnd: undefined,
        valid: true
    };
    @track sortOpts = {
        sortedBy: 'invoiceUrl',
        sortedDirection: 'asc'
    };

    get balance() {
        return parseFloat(this.total || 0).toFixed(5) - parseFloat(this.applied || 0).toFixed(5);
    }

    get customer() {
        return { 
            label: LabelService.customer, 
            value: this.creditMemo ? this.creditMemo.AcctSeed__Customer__r.Name : undefined, 
            link: this.creditMemo ? CommonUtils.getRecordViewPath(this.creditMemo.AcctSeed__Customer__r.Id) : ''
        };
    }

    get ledger() {
        return { 
            label: LabelService.accountingHomeLedger, 
            value: this.creditMemo ? this.creditMemo.AcctSeed__Ledger__r.Name : undefined, 
            link: this.creditMemo ? CommonUtils.getRecordViewPath( this.creditMemo.AcctSeed__Ledger__r.Id ) : ''
        };
    }

    get type() {
        return {
            label: LabelService.commonType,
            value: this.creditMemo ? this.creditMemo.AcctSeed__Type__c : undefined
        };
    }

    get accountingPeriod() {
        return {
            label: LabelService.commonAccountingPeriod,
            value: this.creditMemo ? this.creditMemo.AcctSeed__Accounting_Period__r.Name : undefined,
            link: this.creditMemo ? CommonUtils.getRecordViewPath( this.creditMemo.AcctSeed__Accounting_Period__r.Id ) : ''
        };
    }

    get date() {
        return {
            label: LabelService.commonCreditMemoDate,
            value: this.creditMemo ? this.creditMemo.AcctSeed__Date__c : undefined
        };
    }

    get invoiceSectionTitle() {
        const totalInvoices = this.billingStore.getItems().length;
        const displayMax = this.maxInvoicesDisplayed;
        const displayedInvoices = totalInvoices > displayMax ? displayMax + '+' : totalInvoices;
        return 'Billings - (' + displayedInvoices + ')';
    }

    get maxInvoicesDisplayed() {
        return MAX_INVOICES_LOADED - 1;
    }

    // ==================================
    // Server Calls
    // ==================================

    init() {
        if (!this.recordId) {
            return;
        }

        this.showSpinner(true);
        getCombinedInfo({
            forBillingId: this.recordId,
            maxInvoices: MAX_INVOICES_LOADED,
            filterBy: null 
        })
        .then(results => {
            this.processCombinedInfo(results);
            this.filter = {
                ...this.filter,
                customerId: this.creditMemo.AcctSeed__Customer__r.Id
            };
        })
        .catch(e => this.processError(e))
        .finally(() => this.showSpinner(false));
    }

    loadCombinedInfo() {
        if (!this.recordId) {
            return;
        }

        this.showSpinner(true);
        getCombinedInfo({
            forBillingId: this.recordId,
            maxInvoices: MAX_INVOICES_LOADED,
            filterBy: JSON.stringify(this.filter) 
        })
        .then(results => this.processCombinedInfo(results))
        .then(() => this.resetApplicableItemsGrid())
        .catch(e => this.processError(e))
        .finally(() => this.showSpinner(false));
    }

    loadInvoices() {
        this.showSpinner(true);
        getInvoices({ 
            forBillingId: this.recordId,
            maxInvoices: MAX_INVOICES_LOADED, 
            filterBy: JSON.stringify(this.filter) })
        .then(results => this.processInvoices(results))
        .then(() => this.resetApplicableItemsGrid())
        .catch(e => this.processError(e))
        .finally(() => this.showSpinner(false));
    }  

    save() {
        this.showSpinner(true);
        const updates = this.billingStore.getChanges().map(item => {
            const { billingId, derivedName, appliedDate, variableCredit } = item;
            return { billingId, derivedName, appliedDate, variableCredit };
        });
        return save({ 
            creditMemoId: this.recordId,
            creditMemoLastModifiedDate: this.lastModifiedDate, 
            updates: this.stringifyEach(updates)
        });
    }

    // ==================================
    // Event Handlers
    // ==================================

    handlePopupSave() {
        this.showPopup = false;
        this.loadInvoices();
    }
    
    handlePopupCancel() {
        this.showPopup = false;
    }

    handleFilterChange({detail}) {
        this.filter = {
            ...this.filter,
            postingStatus: detail.postingStatus,
            customerId: detail.customer,
            billingNumber: detail.billingNumber,
            billingDateStart: detail.billingDateStart,
            billingDateEnd: detail.billingDateEnd,
            dueDateStart: detail.dueDateStart,
            dueDateEnd: detail.dueDateEnd,
            billingAmountStart: detail.billingAmountStart,
            billingAmountEnd: detail.billingAmountEnd,
            valid: detail.validFilter
        };
    }

    handleSearch() {
        if (this.filter.valid) {
            if (this.billingStore.getChanges().length > 0) {
                this.showPopup = true;
            } else {
                this.loadInvoices();
            }
        }
    }

    handleCellChange({ detail }) {
        switch (detail.colId) {
            case 'variableCredit':
                this.setCredit(detail);
                break;
            case 'appliedDate':
                this.setAppliedDate(detail);
                break;
            default:
        }
    }

    handleRowAction({ detail }) {
        switch (detail.action.name) {
            case 'apply':
                this.setMaxCredit(detail.row);
                break;
            default:
        }
    }

    handleSort({ detail }) {  
        this.sort(detail.fieldName, detail.sortDirection);
        this.sortOpts.sortedBy = detail.fieldName;
        this.sortOpts.sortedDirection = detail.sortDirection; 
    }

    handleCancel() {
        this.backToRecordHome();
    }

    handleSaveRefresh() {   
        if (this.isValid()) {
            this.save()
                .then(() => this.loadCombinedInfo())
                .then(() => this.displaySaveSuccess())
                .catch(e => this.processError(e))
                .finally(() => this.showSpinner(false));
        }
    }

    handleSaveComplete() {
        if (this.isValid()) {
            this.save()
                .then(() => this.setEditMode(false))
                .then(() => this.displaySaveSuccess())
                .then(() => this.backToRecordHome())
                .catch(e => this.processError(e))
                .finally(() => this.showSpinner(false));
        }
    }

    // ==================================
    // Helpers
    // ==================================

    showSpinner = isShown => { 
        this.isSpinner = isShown;
    }

    initColumns() {
        let columns = [];

        columns.push(...FIXED_COLUMNS.GROUP_ONE);
        

        this.extraColumns.extraColumns.forEach(function (element) {
            columns.push(JSON.parse(element));
        });

        
        columns.push(...FIXED_COLUMNS.GROUP_TWO);

        this.columns = columns;
    }

    applicableItemsGridCmp = () => this.template.querySelector("c-applicable-items");
    resetApplicableItemsGrid() {
        const grid = this.applicableItemsGridCmp();
        if (grid) {
            grid.showFirstPage();
        }
    }

    setEditMode(isEditMode) {
        this.columns = this.columns.filter(this.applyBtnFilter);
        this.billingStore.setEditable(isEditMode);
        this.invoices = this.billingStore.getItems();
    }

    applyBtnFilter = col => !(col.label === '' && col.type === 'button-icon');

    sort(field, direction) {
        if (!this.sortFactory) {
            this.sortFactory = new SortStrategyFactory(this.columns);
        }
        const sortFn = this.sortFactory.getSortStrategy(field, direction);
        this.billingStore.sort(sortFn);
        this.invoices = this.billingStore.getItems();
    }

    processCombinedInfo(data) {
        this.isMultiCurrencyEnabled = data.isMultiCurrencyEnabled;
        this.extraColumns = data.columns;
        this.processCreditMemo(data.creditMemo);
        this.processInvoices(data.invoices);
    }

    processCreditMemo(creditMemo) {
        this.creditMemo = creditMemo;
        this.validateCreditMemo(creditMemo);
        this.lastModifiedDate = creditMemo.LastModifiedDate;
        this.customerName = creditMemo.AcctSeed__Customer__r.Name;
        this.name = creditMemo.AcctSeed__Proprietary_Billing_Number__c 
                    ? creditMemo.AcctSeed__Proprietary_Billing_Number__c
                    : creditMemo.Name;
        this.applied = creditMemo.AcctSeed__Credit_Memo_Applied_Amount__c * -1;
        this.total = Math.abs(creditMemo.AcctSeed__Total__c);
        this.currencyCode = this.getCurrencyCode(creditMemo);
        this.billingStore.setCurrency(this.currencyCode, this.isMultiCurrencyEnabled);
    }

    processInvoices(invoices) {
        this.billingStore.setItems(invoices);
        this.invoices = this.billingStore.getItems();
        this.initColumns();
        this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    displaySaveSuccess() {
        NotificationService.displayToastMessage(this, LabelService.commonChangesSaved, LabelService.commonSaveSuccessful);
    }

    clearErrors(billingId, columnId) {
        this.billingStore.removeError(billingId, columnId);
        this.error = '';
    }

    setAppliedDate({ value: appliedDate, rowId: billingId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(billingId, columnId);
        const invoice = this.billingStore.getItem(billingId);
        const earliestAppliedDate = invoice.earliestAppliedDate;
        invoice.appliedDate = appliedDate;
        this.billingStore.updateItem(invoice);
        if (!appliedDate) {
            this.billingStore.addError(billingId, columnId, VALUE_REQUIRED);
        } else if (appliedDate < earliestAppliedDate) {
            const dateTimeFormat = new Intl.DateTimeFormat(LANG);
            const utcDate = DateUtils.toUTC(new Date(earliestAppliedDate));
            const displayDate = dateTimeFormat.format(utcDate);
            this.billingStore.addError(billingId, columnId, this.labels.ERR_COMMON_GREATER_APPLIED_DATE +' '+ displayDate);
        } else {
            this.clearErrors(billingId, columnId);
        }
        this.invoices = this.billingStore.getItems();
    }

    setCredit({ value: newValue = 0, rowId: billingId, colId: columnId }) {
        const { variableCredit: oldValue, balance: billingBalance } = this.billingStore.getItem(billingId);
        const maxApplicableCredit = (this.balance > billingBalance) ? billingBalance : this.balance;
        const creditDiff = parseFloat((newValue - oldValue).toFixed(5));
        if (newValue >= 0 && maxApplicableCredit >= creditDiff && newValue !== oldValue) {
            this.clearErrors(billingId, columnId);
            this.applyAmount(billingId, creditDiff);
        } else if (newValue < 0) {
            this.billingStore.addError(billingId, columnId, APPLIED_AMOUNT_LESS_THAN_ZERO);
            this.invoices = this.billingStore.getItems();
        } else if (billingBalance < creditDiff) {
            this.billingStore.addError(billingId, columnId, OVERAPPLIED_INVOICE);
            this.invoices = this.billingStore.getItems();
        } else if (parseFloat(this.balance.toFixed(5)) < creditDiff) {
            if (newValue > oldValue) {      // don't display when credit is being unapplied (ie. during correction)
                this.error = OVERAPPLIED_CREDIT;
            }
            this.applyAmount(billingId, creditDiff);
        } else {
            this.applyAmount(billingId, creditDiff);
            this.clearErrors(billingId, columnId);
            this.invoices = this.billingStore.getItems();
        }
    }

    setMaxCredit({ billingId, balance, variableCredit }) {
        let creditAmount;
        if (variableCredit > 0) {           // unapply all credit (negative credit)
            creditAmount = variableCredit * -1;
        } else {                            // apply all credit (positive credit)
            creditAmount = (this.balance > balance) ? balance : this.balance;
        } 
        this.applyAmount(billingId, creditAmount);
    }

    applyAmount(billingId, creditAmount) {        
        // update displayed info
        this.billingStore.applyCredit(creditAmount, billingId);
        this.invoices = this.billingStore.getItems();
        this.applied += creditAmount;
    }

    backToRecordHome() {
        this.navigateToViewRecordPage(this.recordId);
    }

    validationCondition = () => this.balance >= 0 && !this.billingStore.hasErrors();

    isValid() {
        if (this.validationCondition()) {
            this.error = null;
            return true;
        }
        this.displayValidationErrors();
        return false;
    }

    validateCreditMemo(creditMemo) {
        if (creditMemo.AcctSeed__Type__c !== 'Credit Memo') {
            this.error = INCORRECT_BILLING_TYPE;
            this.isError = true;
        }
    }

    clearPageErrors() {
        this.error = undefined;
        this.isError = false;
    }
    
    getCurrencyCode(creditMemo) {
        let isoCode = CURRENCY;
        if (this.isMultiCurrencyEnabled && creditMemo.CurrencyIsoCode) {
            isoCode = creditMemo.CurrencyIsoCode;
        }
        return isoCode;
    }

    displayValidationErrors() {
        const errorRowNames = this.getFieldFromErrorRows('derivedName');
        if (errorRowNames.length > 0) {
            this.displayRowLevelErrors(errorRowNames);
        } else if (this.balance < 0) {
            this.error = OVERAPPLIED_CREDIT;
        }
    }

    getFieldFromErrorRows(fieldName) {
        return this.billingStore.getItems()
            .filter(item => item.errors.length > 0)
            .map(item => item[fieldName]);
    }

    displayRowLevelErrors(errorRowNames) {
        this.error = Labels.ERR_PLEASE_CORRECT_ERROR_FOR_BILLING + ': ' + errorRowNames.reduce(this.commaReducer);
    }

    commaReducer = (acc, s) => { return acc + ', ' + s };

    stringifyEach = xs => xs.map(this.stringify);
    stringify = x => JSON.stringify(x);

}
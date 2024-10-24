import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { DateUtils, SortStrategyFactory, ErrorUtils, LabelService } from "c/utils";
import PayableStore from './payableStore';
import CURRENCY from '@salesforce/i18n/currency';
import LANG from '@salesforce/i18n/lang';
import getPayableInfo from '@salesforce/apex/PayableApplyCreditMemoHelper.getCombinedInfo';
import getPayables from '@salesforce/apex/PayableApplyCreditMemoHelper.getApplicableInvoices';
import save from '@salesforce/apex/PayableApplyCreditMemoHelper.save';
import Labels from './labels';

const INCORRECT_PAYABLE_TYPE = Labels.ERR_PAYABLE_IS_INVOICE_NOT_CREDIT_MEMO;
const OVERAPPLIED_INVOICE = LabelService.errorPayableBalanceCannotBeLessThanZero;
const OVERAPPLIED_CREDIT = LabelService.errorCreditMemoBalanceLessThanZero;
const APPLIED_AMOUNT_LESS_THAN_ZERO = LabelService.errorAppliedAmountLessThanZero;
const APPLIED_DATE_TOO_EARLY = LabelService.errorAppliedDateMustBeGreaterThan + ' ';
const VALUE_REQUIRED = LabelService.commonValueReq;
const MAX_INVOICES_LOADED = 2001;
const KEY_FIELD = 'payableId';

const FIXED_COLUMNS = {
    GROUP_ONE: [
       { 
            label: LabelService.commonPayableNumber, 
            fieldName: 'invoiceUrl',
            type: 'url', 
            sortable: true,
            typeAttributes: { label: {fieldName: 'derivedName'}, target: self }, 
            cellAttributes: { alignment: 'left' }
        }
    ],
    GROUP_TWO: [
        { 
            label: Labels.COMMON_PAYABLE_AMOUNT, 
            fieldName: 'total',
            type: 'customCurrency', 
            sortable: true, 
            typeAttributes: { 
                currencyCode: { fieldName: 'currency' },
                isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}
        },{
            label: Labels.COMMON_TOTAL_APPLIED, 
            fieldName: 'applied', 
            type: 'customCurrency', 
            sortable: true, 
            typeAttributes: { 
                currencyCode: { fieldName: 'currency' },
                isMultiCurrencyEnabled: { fieldName: 'isMultiCurrencyEnabled' }}
        },{ 
            label: Labels.COMMON_PAYABLE_BALANCE, 
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
                title: Labels.COMMON_APPLY, 
                initialWidth: 20,
                iconName: { fieldName: 'applyIcon' },
                disabled: { fieldName: 'isClosed' }}
        },{ 
            label: Labels.COMMON_APPLIED_AMOUNT, 
            fieldName: 'variableCredit', 
            type: 'customCurrency',
            typeAttributes: {
                currencyCode: { fieldName: 'currency' }, 
                disabled: { fieldName: 'isClosed' }, 
                rowId: { fieldName: 'payableId' },
                colId: 'variableCredit',
                errors: { fieldName: 'errors' },
                editMode: { fieldName: 'editable' }}
        },{ 
            label: Labels.COMMON_APPLIED_DATE, 
            fieldName: 'appliedDate', 
            type: 'customDate', 
            initialWidth: 150,
            typeAttributes: {
                disabled: { fieldName: 'isClosed' },
                rowId: { fieldName: 'payableId' },
                colId: 'appliedDate',
                errors: { fieldName: 'errors' },
                editMode: { fieldName: 'editable' }}
        }
    ]
} 

export default class PayableApplyCreditMemo extends NavigationMixin(LightningElement) {
    labels = {...LabelService, ...Labels};
    keyField = KEY_FIELD;
    payableStore = new PayableStore();
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
    payableRowId;
    onHoldError;
    @track onHold;
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
        payableNumber: undefined,
        payeeReference: undefined,
        issueDateStart: undefined,
        issueDateEnd: undefined,
        dueDateStart: undefined,
        dueDateEnd: undefined,
        payableAmountStart: undefined,
        payableAmountEnd: undefined,
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
        let payee = (this.creditMemo && (
            (this.creditMemo.AcctSeed__Vendor__r && this.creditMemo.AcctSeed__Vendor__r.Name) ||
            (this.creditMemo.AcctSeed__Contact__r && this.creditMemo.AcctSeed__Contact__r.Name) ||
            (this.creditMemo.AcctSeed__Employee__r && this.creditMemo.AcctSeed__Employee__r.Name) ||
            null
        )) || null;
        return { 
            label: Labels.COMMON_PAYEE, 
            value: payee,
            link: this.creditMemo ?
                (this.creditMemo.AcctSeed__Vendor__r && this.creditMemo.AcctSeed__Vendor__r.Name) ||
                (this.creditMemo.AcctSeed__Contact__r && this.creditMemo.AcctSeed__Contact__r.Name) ||
                (this.creditMemo.AcctSeed__Employee__r && this.creditMemo.AcctSeed__Employee__r.Name) ||
                null: ''
        };
    }

    get ledger() {
        return { 
            label: LabelService.accountingHomeLedger, 
            value: this.creditMemo ? this.creditMemo.AcctSeed__Ledger__r.Name : undefined, 
            link: this.creditMemo ? this.getRecordViewPath( this.creditMemo.AcctSeed__Ledger__r.Id ) : ''
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
            label: Labels.COMMON_ACCOUNTING_PERIOD,
            value: this.creditMemo ? this.creditMemo.AcctSeed__Accounting_Period__r.Name : undefined,
            link: this.creditMemo ? this.getRecordViewPath( this.creditMemo.AcctSeed__Accounting_Period__r.Id ) : ''
        };
    }

    get date() {
        return {
            label: LabelService.commonCreditMemoDate,
            value: this.creditMemo ? this.creditMemo.AcctSeed__Date__c : undefined
        };
    }

    get invoiceSectionTitle() {
        const totalInvoices = this.payableStore.getItems().length;
        const displayMax = this.maxInvoicesDisplayed;
        const displayedInvoices = totalInvoices > displayMax ? displayMax + '+' : totalInvoices;
        return LabelService.commonPayables + ' - (' + displayedInvoices + ')';
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
        getPayableInfo({
            forpayableId: this.recordId,
            maxInvoices: MAX_INVOICES_LOADED,
            filterBy: null 
        })
        .then(results => {
            this.processCombinedInfo(results);
            this.filter = {
                ...this.filter,
                customerId:
                    (this.creditMemo.AcctSeed__Vendor__r && this.creditMemo.AcctSeed__Vendor__r.Id) ||
                    (this.creditMemo.AcctSeed__Contact__r && this.creditMemo.AcctSeed__Contact__r.Id) ||
                    (this.creditMemo.AcctSeed__Employee__r && this.creditMemo.AcctSeed__Employee__r.Id)
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
        getPayableInfo({
            forpayableId: this.recordId,
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
        getPayables({
            forPayableId: this.recordId,
            maxInvoices: MAX_INVOICES_LOADED, 
            filterBy: JSON.stringify(this.filter) })
        .then(results => this.processInvoices(results))
        .then(() => this.resetApplicableItemsGrid())
        .catch(e => this.processError(e))
        .finally(() => this.showSpinner(false));
    }  

    save() {
        this.showSpinner(true);
        const updates = this.payableStore.getChanges().map(item => {
            const { payableId, derivedName, appliedDate, variableCredit } = item;
            return { payableId, derivedName, appliedDate, variableCredit };
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
            payableNumber: detail.payableNumber,
            payeeReference: detail.payeeReference,
            issueDateStart: detail.issueDateStart,
            issueDateEnd: detail.issueDateEnd,
            dueDateStart: detail.dueDateStart,
            dueDateEnd: detail.dueDateEnd,
            payableAmountStart: detail.payableAmountStart,
            payableAmountEnd: detail.payableAmountEnd,
            valid: detail.validFilter
        };
    }

    handleSearch() {
        if (this.filter.valid) {
            if (this.payableStore.getChanges().length > 0) {
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
        this.payableRowId = detail.row.payableId;
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
        else if (!this.isValid()){
            this.displayValidationErrors();
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
        }else if(!this.isValid())
        {
            this.displayValidationErrors();
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
        this.payableStore.setEditable(isEditMode);
        this.invoices = this.payableStore.getItems();
    }

    applyBtnFilter = col => !(col.label === '' && col.type === 'button-icon');

    sort(field, direction) {
        if (!this.sortFactory) {
            this.sortFactory = new SortStrategyFactory(this.columns);
        }
        const sortFn = this.sortFactory.getSortStrategy(field, direction);
        this.payableStore.sort(sortFn);
        this.invoices = this.payableStore.getItems();
    }

    processCombinedInfo(data) {
        this.isMultiCurrencyEnabled = data.isMultiCurrencyEnabled;
        this.extraColumns = data.columns;
        this.displayCreditMemo(data.creditMemo);
        this.processInvoices(data.invoices);        
    }

    displayCreditMemo(creditMemo) {
        this.onHold = creditMemo.onHold;
        this.creditMemo = creditMemo;
        this.validateCreditMemo(creditMemo);
        this.lastModifiedDate = creditMemo.LastModifiedDate;
        this.customerName = creditMemo.AcctSeed__Payee_Reference__c;
        this.name = creditMemo.AcctSeed__Proprietary_Payable_Number__c 
                    ? creditMemo.AcctSeed__Proprietary_Payable_Number__c
                    : creditMemo.Name;
        this.applied = creditMemo.AcctSeed__Credit_Memo_Applied_Amount__c * -1;
        this.total = Math.abs(creditMemo.AcctSeed__Total__c);
        this.currencyCode = this.getCurrencyCode(creditMemo);
        this.payableStore.setCurrency(this.currencyCode, this.isMultiCurrencyEnabled);
    }

    processInvoices(invoices) {
        this.payableStore.setItems(invoices);
        this.invoices = this.payableStore.getItems();
        this.initColumns();
        this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    displaySaveSuccess() {
        this.dispatchEvent(new ShowToastEvent({
            title: LabelService.COMMON_SAVE_SUCCESSFUL,
            message: Labels.X_DATA_SAVED_SUCCESSFULLY,
            variant: 'success'
        }));
    }

    clearErrors(payableId, columnId) {
        this.payableStore.removeError(payableId, columnId);
        this.error = '';
    }

    setAppliedDate({ value: appliedDate, rowId: payableId, colId: columnId }) {
        //clear any errors off first for this column
        this.clearErrors(payableId, columnId);
        const invoice = this.payableStore.getItem(payableId);
        const earliestAppliedDate = invoice.earliestAppliedDate;
        invoice.appliedDate = appliedDate;
        this.payableStore.updateItem(invoice);
        if (!appliedDate) {
            this.payableStore.addError(payableId, columnId, VALUE_REQUIRED);
        } else if (appliedDate < earliestAppliedDate) {
            const dateTimeFormat = new Intl.DateTimeFormat(LANG);
            const utcDate = DateUtils.toUTC(new Date(earliestAppliedDate));
            const displayDate = dateTimeFormat.format(utcDate);
            this.payableStore.addError(payableId, columnId, this.labels.ERR_COMMON_GREATER_APPLIED_DATE +' '+ displayDate);
        } else {
            this.clearErrors(payableId, columnId);
        }
        this.invoices = this.payableStore.getItems();
    }

    setCredit({ value: newValue = 0, rowId: payableId, colId: columnId }) {
        const { variableCredit: oldValue, balance: payableBalance } = this.payableStore.getItem(payableId);
        const maxApplicableCredit = (this.balance > payableBalance) ? payableBalance : this.balance;
        const creditDiff = parseFloat((newValue - oldValue).toFixed(5));
        if (newValue >= 0 && maxApplicableCredit >= creditDiff && newValue !== oldValue) {
            this.clearErrors(payableId, columnId);
            this.applyAmount(payableId, creditDiff);
        } else if (newValue < 0) {
            this.payableStore.addError(payableId, columnId, APPLIED_AMOUNT_LESS_THAN_ZERO);
            this.invoices = this.payableStore.getItems();
        } else if (payableBalance < creditDiff) {
            this.payableStore.addError(payableId, columnId, OVERAPPLIED_INVOICE);
            this.invoices = this.payableStore.getItems();
        } else if (parseFloat(this.balance.toFixed(5)) < creditDiff) {
            if (newValue > oldValue) {      // don't display when credit is being unapplied (ie. during correction)
                this.error = OVERAPPLIED_CREDIT;
            }
            this.applyAmount(payableId, creditDiff);
        } else {
            this.applyAmount(payableId, creditDiff);
            this.clearErrors(payableId, columnId);
            this.invoices = this.payableStore.getItems();
        }
    }

    setMaxCredit({ payableId, balance, variableCredit }) {
        let creditAmount;
        if (variableCredit > 0) {           // unapply all credit (negative credit)
            creditAmount = variableCredit * -1;
        } else {                            // apply all credit (positive credit)
            creditAmount = (this.balance > balance) ? balance : this.balance;
        } 
        this.applyAmount(payableId, creditAmount);
    }

    applyAmount(payableId, creditAmount) {        
        // update displayed info
        this.payableStore.applyCredit(creditAmount, payableId);
        this.invoices = this.payableStore.getItems();
        this.applied += creditAmount;
    }

    backToRecordHome() { 
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                "actionName": "view"
            }
        });
    }

    getRecordViewPath = recordId => '/lightning/r/' + recordId + '/view';

    validationCondition = () => this.balance >= 0 && !this.payableStore.hasErrors();

    isValid() {
        
        if (this.isPayableOnHold()) {
            this.onHoldError = true;
            this.displayValidationErrors();
            return false;
        }
        if (this.validationCondition()) {            
            this.error = null;
            return true;
        }
    }

    isPayableOnHold() {
        const onHoldPayables = this.payableStore.getItems().find(payable => {
            return payable.payableId === this.payableRowId;
        });
        if(onHoldPayables.onHold === true){
            return true;
        }
        return false;
        
    }
    validateCreditMemo(creditMemo) {
        if (creditMemo.AcctSeed__Type__c !== 'Credit Memo') {
            this.error = INCORRECT_PAYABLE_TYPE;
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
        }else if (this.onHoldError === true ){
            this.error = Labels.ERR_CREDIT_MEMO_TO_A_PAYABLE_WITH_ON_HOLD;
        }
    }

    getFieldFromErrorRows(fieldName) {
        return this.payableStore.getItems()
            .filter(item => item.errors.length > 0)
            .map(item => item[fieldName]);
    }

    displayRowLevelErrors(errorRowNames) {
        this.error = Labels.ERR_PLEASE_CORRECT_PAYABLE_ERRORS + errorRowNames.reduce(this.commaReducer);
    }

    commaReducer = (acc, s) => { return acc + ', ' + s };

    stringifyEach = xs => xs.map(this.stringify);
    stringify = x => JSON.stringify(x);

}
import {api, track} from 'lwc';
import {AmortizationEntry, Billing, FixedAsset, Payable} from 'c/sobject';
import { DateUtils, ErrorUtils, LabelService, Constants } from "c/utils";
import WizardItem from 'c/wizardItem';
import isAccountingPeriodsValid from '@salesforce/apex/AmortizationHelper.isAccountingPeriodsValid';
import Labels from './labels';
const ACCOUNTING_PERIODS_ERROR = Labels.ERR_NO_OPEN_ACCOUNTING_PERIOD_IN_DATE_RANGE_AMORTIZATION;

const HELP_TEXTS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: {
        amount: LabelService.depreciateWizardAmountHelpText,
        period: LabelService.depreciateWizardPeriodHelpText,
        startDate: LabelService.depreciateWizardStartDateHelpText,
        endDate: LabelService.depreciateWizardEndDateHelpText
    },
    [Billing.objectApiName]: {
        amount: LabelService.amortizationWizardAmountHelpText,
        period: LabelService.amortizationWizardPeriodHelpText,
        startDate: LabelService.amortizationWizardStartDateHelpText,
        endDate: LabelService.amortizationWizardEndDateHelpText
    },
    [Payable.objectApiName]: {
        amount: LabelService.amortizationWizardAmountHelpText,
        period: LabelService.amortizationWizardPeriodHelpText,
        startDate: LabelService.amortizationWizardStartDateHelpText,
        endDate: LabelService.amortizationWizardEndDateHelpText
    }
};

const AMOUNT_GREATER_WARNING_MSGS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: ({fixedAssetName}) => LabelService.depreciateWizardAmountGreaterWarningMsg?.replace('{0}', fixedAssetName),
    [Billing.objectApiName]: ({sobjectLabel}) => LabelService.amortizationWizardAmountGreaterWarningMsg?.replace('{0}', sobjectLabel),
    [Payable.objectApiName]: ({sobjectLabel}) => LabelService.amortizationWizardAmountGreaterWarningMsg?.replace('{0}', sobjectLabel)
};

export default class AmortizationWizardTermInfo extends WizardItem {
    @api sObjectName;
    @api sobjectLabel;
    @api existingAmountsSum;
    @api total;
    @api accountingSettingData;
    @api recordName;
    @api acctMethodData;

    @track minEndDate;
    @track isAmountGreater = false;
    @track isStraightLineDailyChosen = false;
    @track amountValue;

    error;
    startDateValue;
    endDateValue;
    periodNumberValue;
    accountingPeriodsWrapper = {
        startDate : undefined,
        endDate : undefined,
        periodNumber : undefined,
        isError : false,
    };
    labels = {...LabelService, ...Labels};

    get isShowAmortizeDeferredToggle() {
        return (new Set([Billing.objectApiName, Payable.objectApiName])).has(this.sObjectName);
    }

    //getter used to dynamically fetch helptext related to billing or payables
    get helptext() {
        let helptext = this.labels.DEFAULT_REVENUE_GL_ACCOUNT_LINES_ONLY_HELPTEXT;
        if(this.sobjectLabel === this.labels.COMMON_BILLING) {
            helptext = helptext.replace('{0}', this.labels.COMMON_BILLING.toLowerCase()).replace('{1}', this.labels.COMMON_DEFERRED_REVENUE).replace('{2}', this.labels.COMMON_BILLING.toLowerCase());
        }
        else if(this.sobjectLabel === this.labels.COMMON_PAYABLE) {
            helptext = helptext.replace('{0}', this.labels.COMMON_PAYABLE.toLowerCase()).replace('{1}', this.labels.COMMON_DEFERRED_EXPENSE).replace('{2}', this.labels.COMMON_PAYABLE.toLowerCase());
        }
        return helptext;
    }

    get amountGreaterWarningMsg() {
        return AMOUNT_GREATER_WARNING_MSGS_BY_SOBJECT_NAMES[this.sObjectName]?.({fixedAssetName: this.recordName, sobjectLabel: this.sobjectLabel});
    }

    get isFixedAsset() {
        return this.sObjectName === FixedAsset.objectApiName;
    }

    get amountValue() {
        return this.values[this.amortizationEntry.amount];
    }

    get descriptionValue() {
        return this.values[this.amortizationEntry.description];
    }

    get accrualCashValue() {
        return this.values['accrualCash'];
    }

    get isDisableAccrualCash() {
        return this.acctMethodData?.ledgerAcctMethod !== Constants.LEDGER.ACCT_METHOD_ACCRUAL_CASH;
    }

    get minEndDateMessage() {
        return this.minEndDate && `${Labels.INF_VALUE_MUST_BE} ${DateUtils.getFormattedDate(this.minEndDate)} ${Labels.INF_OR_LATER}.`
    }

    //getter used to get the value of AcctSeed__Amortize_Default_Revenue_Prepaid_Expense__c
    get toggleValue() {
        return (this.values.hasOwnProperty('toggleButton') ? this.values['toggleButton'] : this.accountingSettingData.AcctSeed__Amortize_Default_Revenue_Prepaid_Expense__c);
    }

    get isShowAccrualCashInSeparateLine() {
        return !this.isStraightLineDailyChosen;
    }

    get isShowAccrualCashInLine() {
        return this.isStraightLineDailyChosen;
    }

    connectedCallback() {
        this.helpTexts = HELP_TEXTS_BY_SOBJECT_NAMES[this.sObjectName] || {};

        this.amountValue = this.toggleValue && this.isShowAmortizeDeferredToggle
            ? this.values['lineSubTotal']
            : this.values[this.amortizationEntry.amount];

        this.minEndDate = this.values.hasOwnProperty('startDate') && this.values['startDate'];
        this.startDateValue = this.accountingPeriodsWrapper.startDate = this.values.hasOwnProperty('startDate') && this.values['startDate'];
        this.endDateValue = this.accountingPeriodsWrapper.endDate = this.values.hasOwnProperty('endDate') && this.values['endDate'];
        this.periodNumberValue = this.accountingPeriodsWrapper.periodNumber = this.values.hasOwnProperty('accountingPeriodsNumber') && this.values['accountingPeriodsNumber'];
        this.isPeriodValid = true;
        this.startDateValue && (this.endDateValue || this.periodNumberValue) && this.calculateAndSetPeriods();

        this.setIsAmountGreaterFlag(this.amountValue);

        if (this._values.selectedMethod === 'straight line - daily') {
            this.isStraightLineDailyChosen = true;
        } else {
            this.isStraightLineDailyChosen = false;
        }
    }

    validateAndRetrieve({isSkipValidation} = {isSkipValidation : false}) {
        const inputs = this.template.querySelectorAll('lightning-input,lightning-textarea,lightning-combobox');

        let isValid = true;
        let data = {};
        inputs && inputs.forEach(input => {
            if (!isSkipValidation && input.dataset.field === 'endDate' && input.value === '') {
                input.setCustomValidity(this.labels.endDateCantEmpty);
                input.reportValidity();
                isValid = false;
            }
            else if (!isSkipValidation && !input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
            data[input.dataset.field] = input.type !== 'toggle' ? input.value : input.checked;
        });
        !this.isPeriodValid && (isValid = false);
        isValid = isValid && this.validatePeriodCount();

        return {isValid, data};
    }

    validatePeriodCount() {
        const isValid = true;
        if (this.isFixedAsset) {
            const endDate = this.endDate();
            if (endDate && this.monthsBetweenDates(this.startDateValue, this.endDateValue) > 60) {
                endDate.setCustomValidity(LabelService.depreciateWizardNumberPeriodOver);
            } else if (endDate) {
                endDate.setCustomValidity('');
            }
        }
        return isValid;
    }

    monthsBetweenDates(startDate, endDate) {
        if (!startDate || !endDate) {
            return 0;
        }
        startDate = startDate && (new Date(startDate));
        endDate = endDate && (new Date(endDate));

        const startYear = startDate.getFullYear();
        const startMonth = startDate.getMonth();
        const endYear = endDate.getFullYear();
        const endMonth = endDate.getMonth();

        const yearsDiff = endYear - startYear;
        const monthsDiff = endMonth - startMonth;

        let totalMonths = yearsDiff * 12 + monthsDiff;

        if (endDate.getDate() < startDate.getDate()) {
            totalMonths--;
        }

        return totalMonths;
    }

    handleSetStartDate() {
        this.minEndDate = this.startDateValue = this.accountingPeriodsWrapper.startDate = this.startDate().value;
        this.calculateAndSetPeriods();
        this.validatePeriodCount();
    }

    handleSetEndDate() {
        this.endDateValue = this.accountingPeriodsWrapper.endDate = this.endDate().value;
        this.endDateValue && (this.accountingPeriodsWrapper.periodNumber = null);
        this.calculateAndSetPeriods();
        this.validatePeriodCount();
    }

    handleSetNumberPeriod() {
        this.periodNumberValue = this.accountingPeriodsWrapper.periodNumber = this.period().value;
        if (this.periodNumberValue && this.periodNumberValue !== "") {
            this.accountingPeriodsWrapper.endDate = null;
            this.calculateAndSetPeriods();
        }
    }

    handleAmountChange(e) {
        this.setIsAmountGreaterFlag(e.currentTarget.value);
    }

    /**
     *
     * @param {*} event - to get DOM values
     * Description - Method used to show subltotal of lines of billing/payable lines on checking this toggle
     */
    handleToggle(event) {
        let isChecked = event.detail.checked;
        this.values = {...this.values, ...{toggleButton: isChecked}};
        this.amountValue = isChecked ? this.values['lineSubTotal'] : this.values['_initialAmount'];

        const toggleEvent = new CustomEvent('changetoggle', {
            detail: {fieldName: 'toggleButton', value: isChecked}
        });
       this.dispatchEvent(toggleEvent);

       this.setIsAmountGreaterFlag(this.amountValue);
    }

    setIsAmountGreaterFlag(amount) {
        this.isAmountGreater = Math.abs((this.existingAmountsSum || 0) + (amount * 1)) > (this.toggleValue && this.isShowAmortizeDeferredToggle
            ? Math.abs(this.values['lineSubTotal']) : Math.abs(this.total));
    }

    calculateAndSetPeriods() {
        this.isPeriodValid = false;
        this.resetErrors();
        this.accountingPeriodsWrapper.periodNumber = !this.accountingPeriodsWrapper.periodNumber ? null : this.accountingPeriodsWrapper.periodNumber;
        this.accountingPeriodsWrapper.endDate = !this.accountingPeriodsWrapper.endDate ? null : this.accountingPeriodsWrapper.endDate;
        if (this.startDateValue && (this.endDateValue || this.periodNumberValue)) {
            this.validatePeriods();
        }
    }

    validatePeriods() {
        return isAccountingPeriodsValid({periodInfo: JSON.stringify(this.accountingPeriodsWrapper)})
          .then(result => {
              this.accountingPeriodsWrapper = result;
              this.endDateValue = result.endDate;
              this.periodNumberValue = result.periodNumber;
              if (!result.isError) {
                  this.isPeriodValid = true;
              }
              else {
                  this.error = ACCOUNTING_PERIODS_ERROR;
              }
          })
          .catch(e => this.processError(e));
    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    resetErrors = () => {this.error = null};
    startDate = () => this.template.querySelector('.start-date');
    endDate = () => this.template.querySelector('.end-date');
    period = () => this.template.querySelector('.period-number');

    amortizationEntry = new AmortizationEntry();
}
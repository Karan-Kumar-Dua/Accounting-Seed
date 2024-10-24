import {api, track, wire} from 'lwc';
import Wizard from 'c/wizard';
import { AmortizationEntry, FixedAsset, Billing, Payable, Ledger } from "c/sobject";
import {getPicklistValues, getObjectInfos} from 'lightning/uiObjectInfoApi';
import {getRecord, getFieldValue, getFieldDisplayValue} from 'lightning/uiRecordApi';
import {NotificationService, CommonUtils, ErrorUtils, LabelService} from "c/utils";
import invokeCreateEntries from '@salesforce/apex/AmortizationHelper.createEntries';
import invokeFetchSettings from '@salesforce/apex/AmortizationHelper.fetchSettings';
import getAccountingInfo from '@salesforce/apex/AmortizationHelper.getAccountingInfo';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import Labels from './labels';

const SELECT_METHOD = {name: Labels.INF_SELECT_METHOD_TEXT, id: 'selectMethod'};
const TERM_INFORMATION = {name: Labels.INF_TERM_INFORMATION, id: 'termInformation'};
const ACCOUNTING_INFORMATION_CREATE = {name: Labels.INF_ACCOUNTING_INFORMATION_AND_CREATE, id: 'accountingInformationCreate'};

const INFO_MSGS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: LabelService.depreciateWizardInfoMsg,
    [Billing.objectApiName]: LabelService.amortizationWizardInfoMsg,
    [Payable.objectApiName]: LabelService.amortizationWizardInfoMsg
};

const TITLE_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: LabelService.depreciateWizardTitle,
    [Billing.objectApiName]: LabelService.amortizationWizardTitle,
    [Payable.objectApiName]: LabelService.amortizationWizardTitle
};

const FIELDS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: [
        FixedAsset.name_field,
        FixedAsset.ledger,
        FixedAsset.ledger_r_name,
        FixedAsset.ledger_r_acct_method,
        FixedAsset.value
    ],
    [Billing.objectApiName]: [
        Billing.name_field,
        Billing.proprietary_billing_number,
        Billing.billing_cycle_start_date,
        Billing.billing_cycle_end_date,
        Billing.date,
        Billing.customer,
        Billing.customer_r_name,
        Billing.ledger,
        Billing.ledger_r_name,
        Billing.ledger_r_acct_method,
        Billing.total,
        Billing.ledger_amount
    ],
    [Payable.objectApiName]: [
        Payable.name_field,
        Payable.proprietary_payable_number,
        Payable.date,
        Payable.vendor,
        Payable.vendor_r_name,
        Payable.contact,
        Payable.contact_r_name,
        Payable.employee,
        Payable.employee_r_name,
        Payable.ledger,
        Payable.ledger_r_name,
        Payable.ledger_r_acct_method,
        Payable.total,
        Payable.ledger_amount
    ]
};

const EXTRACTORS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: () => ({
        recordLabel: 'Fixed Asset',
        nameField: FixedAsset.name_field,
        valueField: FixedAsset.value,
        isShowValueSection: true,
        ledgerField: FixedAsset.ledger,
        ledgerNameField: FixedAsset.ledger_r_name,
        helpLink: 'https://support.accountingseed.com/hc/en-us/articles/18475928064915',
        amountField: FixedAsset.value,
        accrualCashField: FixedAsset.ledger_r_acct_method
    }),
    [Billing.objectApiName]: commonRecord => ({
        recordLabel: LabelService.commonBilling,
        nameField: getFieldValue(commonRecord, Billing.proprietary_billing_number)
            && Billing.proprietary_billing_number
            || Billing.name_field,
        customerField: Billing.customer,
        customerNameField: Billing.customer_r_name,
        isShowCustomerSection: true,
        ledgerField: Billing.ledger,
        ledgerNameField: Billing.ledger_r_name,
        helpLink: 'https://support.accountingseed.com/hc/en-us/articles/4411545920275',
        startDateField: (getFieldValue(commonRecord, Billing.billing_cycle_start_date) && Billing.billing_cycle_start_date)
            || (getFieldValue(commonRecord, Billing.date) && Billing.date),
        endDateField: Billing.billing_cycle_end_date,
        amountField: Billing.ledger_amount,
        accrualCashField: Billing.ledger_r_acct_method
    }),
    [Payable.objectApiName]: commonRecord => ({
        recordLabel: LabelService.commonPayable,
        nameField: getFieldValue(commonRecord, Payable.proprietary_payable_number)
            && Payable.proprietary_payable_number
            || Payable.name_field,
        customerField: (getFieldValue(commonRecord, Payable.vendor) && Payable.vendor)
            || (getFieldValue(commonRecord, Payable.contact) && Payable.contact)
            || (getFieldValue(commonRecord, Payable.employee) && Payable.employee),
        customerNameField: (getFieldValue(commonRecord, Payable.vendor) && Payable.vendor_r_name)
            || (getFieldValue(commonRecord, Payable.contact) && Payable.contact_r_name)
            || (getFieldValue(commonRecord, Payable.employee) && Payable.employee_r_name),
        isShowCustomerSection: true,
        ledgerField: Payable.ledger,
        ledgerNameField: Payable.ledger_r_name,
        helpLink: 'https://support.accountingseed.com/hc/en-us/articles/4411562773651',
        startDateField: Payable.date,
        amountField: Payable.ledger_amount,
        accrualCashField: Payable.ledger_r_acct_method
    })
};

const SUCCESS_MSGS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: {
        create: LabelService.depreciateWizardSuccessCreateMsg,
        createAndPost: LabelService.depreciateWizardSuccessCreatePostMsg
    },
    [Billing.objectApiName]: {
        create: LabelService.amortizationWizardSuccessCreateMsg,
        createAndPost: LabelService.amortizationWizardSuccessCreatePostMsg
    },
    [Payable.objectApiName]: {
        create: LabelService.amortizationWizardSuccessCreateMsg,
        createAndPost: LabelService.amortizationWizardSuccessCreatePostMsg
    }
};

export default class AmortizationWizard extends Wizard {
    labels = {...LabelService, ...Labels};
    @api recordId;
    @api sObjectName;
    @api callBacks;
    @api ltngOut;

    @track currentStep = {...SELECT_METHOD};
    @track commonInfos;
    @track isHideAmortizeRevenueModal = false;
    @track accountingSettingData;

    billing = Billing;
    payable = Payable;
    amortizationEntry = new AmortizationEntry();

    pathItems = [
        {...SELECT_METHOD},
        {...TERM_INFORMATION},
        {...ACCOUNTING_INFORMATION_CREATE}
    ];

    methodOptions;

    showSpinner = true;

    errors;
    ledgerDefaultRecordTypeId;

    get infoMessage() {
        return INFO_MSGS_BY_SOBJECT_NAMES[this.sObjectName];
    }

    get title() {
        return TITLE_BY_SOBJECT_NAMES[this.sObjectName];
    }

    get isSelectMethodStep() {
        return this.currentStep.id === SELECT_METHOD.id;
    }

    get isTermInformationStep() {
        return this.currentStep.id === TERM_INFORMATION.id;
    }

    get isAccountingInfoCreateStep() {
        return this.currentStep.id === ACCOUNTING_INFORMATION_CREATE.id;
    }

    get amortizeRevenueModalClasses() {
        return this.isHideAmortizeRevenueModal && CommonUtils.computeClasses(['slds-hide']);
    }

    get isDisableNextBtn() {
        return this.showSpinner || !this.methodOptions || !this.methodOptions.length;
    }

    async fetchAccountingSetting() {
        try {
            this.accountingSettingData = await getSettings();
        }
        catch (err) {
            console.error(err);
        }

    }

    connectedCallback() {
        this.fetchAccountingSetting();
        this.objectApiNames = [this.sObjectName, Ledger.objectApiName, AmortizationEntry.objectApiName];
        this.fields = [...FIELDS_BY_SOBJECT_NAMES[this.sObjectName]];
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$fields'
    })
    fetchCommonRecord({data, error}) {
        this.commonRecord = data;
        this.initCommonInfo();
    }

    @wire(getPicklistValues, { recordTypeId: '$ledgerDefaultRecordTypeId', fieldApiName: Ledger.acctMethod })
    fetchAcctMethodValues({data}) {
        data && (this.acctMethodData = {
            ...(this.acctMethodData || {}),
            acctMethodOptions: data.values.map(item => ({
                label: item.label,
                value: item.value
            }))
        });
    }

    @wire(getObjectInfos, { objectApiNames: '$objectApiNames' })
    fetchSObjectInfos({data}) {
        data && data.results
            .filter(result => result.statusCode === 200)
            .forEach(statusResult => {
                if (statusResult.result.apiName === this.sObjectName) {
                    this.sObjectInfo = statusResult.result;
                    this.sobjectLabel = this.sObjectInfo && this.sObjectInfo.label;
                    this.initCommonInfo();
                } else if (statusResult.result.apiName === Ledger.objectApiName) {
                    this.ledgerDefaultRecordTypeId = statusResult.result.defaultRecordTypeId;
                } else if (statusResult.result.apiName === AmortizationEntry.objectApiName) {
                    this.acctMethodData = {
                        ...(this.acctMethodData || {}),
                        accrualCashFieldLabel: statusResult.result.fields[AmortizationEntry.accrual_cash.fieldApiName]?.label
                    };
                }
            });
    }

    @wire(invokeFetchSettings, {recordId: '$recordId'})
    fetchSettings({data}) {
        data && (
            this.showSpinner = false,
            this.isAutoPostEnabled = data.isAutoPostEnabled,
            this.existingAmountsSum = data.existingAmountsSum,
            this.methodOptions = data.methodOptions
        );
    }

    @wire(getAccountingInfo, {recordId: '$recordId'})
    wiredRecord({data}) {
        if (data) {
            this.currentStep[this.amortizationEntry.product] = data.product;
            this.currentStep[this.amortizationEntry.project] = data.project;
            this.currentStep[this.amortizationEntry.project_task] = data.projectTask;
            this.currentStep[this.amortizationEntry.gl_variable1] = data.glVariable1;
            this.currentStep[this.amortizationEntry.gl_variable2] = data.glVariable2;
            this.currentStep[this.amortizationEntry.gl_variable3] = data.glVariable3;
            this.currentStep[this.amortizationEntry.gl_variable4] = data.glVariable4;
            this.currentStep[this.amortizationEntry.debit_gl_account] = data.debitGlAccount;
            this.currentStep[this.amortizationEntry.credit_gl_account] = data.creditGlAccount;
            this.currentStep['lineSubTotal'] = data.lineSubTotal;
            this.currentStep['amortizeDefaultRevenuePrepaidExpense'] = this.accountingSettingData && this.accountingSettingData.AcctSeed__Amortize_Default_Revenue_Prepaid_Expense__c;
            this.total = data.initialAmount;
            this.currentStep[this.amortizationEntry.amount] = data.initialAmount;
            //intialAmount used to hold initialtotal of billing/payable without interference of toggle box
            this.currentStep['_initialAmount'] = data.initialAmount;
        }
    }

    initCommonInfo() {
        if (this.sObjectInfo && this.commonRecord) {
            this.currentStep['sourceDocumentId'] = this.recordId;
            const {
                recordLabel,
                nameField,

                valueField,
                isShowValueSection,

                customerField,
                customerNameField,
                isShowCustomerSection,

                ledgerField,
                ledgerNameField,

                helpLink,

                startDateField,
                endDateField,

                amountField,
                accrualCashField
            } = EXTRACTORS_BY_SOBJECT_NAMES[this.sObjectName](this.commonRecord);

            this.recordName = getFieldValue(this.commonRecord, nameField);
            this.commonInfos = [
                {
                    containerClass: 'common-info--name slds-p-right_x-small',
                    label: recordLabel,
                    displayValue: getFieldValue(this.commonRecord, nameField),
                    value: `/${this.recordId}`,
                    field: nameField.fieldApiName,
                    isLinkType: true,
                    size: isShowCustomerSection ? 3 : 5
                },
                isShowCustomerSection && {
                    containerClass: 'common-info--customer',
                    label: this.getFieldFromObjectInfo(customerField.fieldApiName, this.sObjectInfo).label,
                    displayValue: getFieldValue(this.commonRecord, customerNameField),
                    value: `/${getFieldValue(this.commonRecord, customerField)}`,
                    field: customerField.fieldApiName,
                    isLinkType: true,
                    size: 5
                },
                isShowValueSection && {
                    containerClass: 'common-info--value',
                    label: this.getFieldFromObjectInfo(valueField.fieldApiName, this.sObjectInfo).label,
                    displayValue: getFieldDisplayValue(this.commonRecord, valueField),
                    value: getFieldValue(this.commonRecord, valueField),
                    field: valueField.fieldApiName,
                    isCurrencyType: true,
                    size: 3
                },
                {
                    containerClass: 'common-info--ledger',
                    label: this.getFieldFromObjectInfo(ledgerField.fieldApiName, this.sObjectInfo).label,
                    displayValue: getFieldValue(this.commonRecord, ledgerNameField),
                    value: `/${getFieldValue(this.commonRecord, ledgerField)}`,
                    field: ledgerField.fieldApiName,
                    isLinkType: true,
                    size: 3
                },
                {
                    containerClass: 'common-info--help',
                    displayValue: LabelService.commonHelp,
                    value: helpLink,
                    field: 'help',
                    isLinkType: true,
                    size: 1
                }
            ].filter(item => item);

            this.currentStep['startDate'] = startDateField && getFieldValue(this.commonRecord, startDateField);
            this.currentStep['endDate'] = endDateField && getFieldValue(this.commonRecord, endDateField);
            this.currentStep['ledgerId'] = getFieldValue(this.commonRecord, ledgerField);
            this.currentStep['accrualCash'] = accrualCashField && getFieldValue(this.commonRecord, accrualCashField);
            this.acctMethodData = { ...(this.acctMethodData || {}), ledgerAcctMethod: this.currentStep['accrualCash'] };
        }
    }

    handleToggle(event) {
        this.currentStep['amortizeDefaultRevenuePrepaidExpense'] = event.detail.value;
    }

    getFieldFromObjectInfo = (fieldApiName, objectInfo) => {
        if (objectInfo && objectInfo.fields.hasOwnProperty(fieldApiName)) {
            return objectInfo.fields[fieldApiName];
        }
    }

    goNext() {
        super.goNext(() => {this.goToPathItem(this.currentStep.id);});
    }

    goBack(event, prevStep) {
        this.clearErrors();
        super.goBack(prevStep, () => {this.goToPathItem(this.currentStep.id);});
    }

    handlePreviewCalculations() {
        let isValidPeriod = true;
        if (this.currentStep.id === TERM_INFORMATION.id) {
            const amortizationWizardStep = this.template.querySelector('[data-wizard-step]');
            const {isValid, data} = amortizationWizardStep && amortizationWizardStep.validateAndRetrieve();
            isValidPeriod = isValid;
            isValidPeriod && (this.currentStep = {...this.currentStep, ...data})
        }

        if (isValidPeriod) {
            const previewCalculationsModal = this.template.querySelector('c-modal-popup-base[data-id="previewCalculationsModal"]');
            previewCalculationsModal && previewCalculationsModal.openModal();
            this.isHideAmortizeRevenueModal = true;
        }
    }

    closePreviewCalculations() {
        const previewCalculationsModal = this.template.querySelector('c-modal-popup-base[data-id="previewCalculationsModal"]');
        previewCalculationsModal && previewCalculationsModal.closeModal();
        this.isHideAmortizeRevenueModal = false;
    }

    createEntriesPreviewCalculations() {
        this.closePreviewCalculations();
        this.createEntries();
    }

    createEntries() {
        this.clearErrors();
        const amortizationWizardStep = this.template.querySelector('[data-wizard-step]');
        const {isValid, data} = amortizationWizardStep && amortizationWizardStep.validateAndRetrieve();
        isValid && (this.currentStep = {...this.currentStep, ...data}) && (this.showSpinner = true) &&
            invokeCreateEntries({params: this.currentStep})
                .then((result) => {
                    if (result.isSuccess) {
                        NotificationService.displayToastMessage(
                            this,
                            this.isAutoPostEnabled
                                ? SUCCESS_MSGS_BY_SOBJECT_NAMES[this.sObjectName]?.createAndPost
                                : SUCCESS_MSGS_BY_SOBJECT_NAMES[this.sObjectName]?.create
                        );
                        this.closeQuickAction({isNeedRefresh: true});
                    } else {
                        this.errors = result.errors && result.errors[0];
                    }
                })
                .catch(e => this.processError(e))
                .finally(() => {this.showSpinner = false});
    }

    goToPathItem(pathItemId) {
        const path = this.template.querySelector('c-path');
        path && path.goToItem(pathItemId);
    }

    openModal() {
        const amortizeRevenueModal = this.template.querySelector('c-modal-popup-base[data-id="amortizeRevenueModal"]');
        amortizeRevenueModal && amortizeRevenueModal.openModal();
    }

    closeQuickAction(detail = {isNeedRefresh: false}) {
        this.dispatchEvent(new CustomEvent('closequickaction', {detail}));
        this.callBacks && this.callBacks.backToRecord && this.callBacks.backToRecord();
    }

    handleItemClick(event) {
        const ONE_STEP = 1;
        const gotoPathItemId = event.detail.value;

        const gotoPathItemIndex = this.pathItems.findIndex(item => item.id === gotoPathItemId);
        const currentStepIndex = this.pathItems.findIndex(item => item.id === this.currentStep.id);

        gotoPathItemIndex > currentStepIndex && gotoPathItemIndex - currentStepIndex === ONE_STEP &&
            this.goNext();

        gotoPathItemIndex < currentStepIndex &&
            this.goBack({}, this.pathItems[gotoPathItemIndex]);
    }

    processError(e) {
        const {error} = ErrorUtils.processError(e);
        this.errors = error;
    }

    clearErrors() {
        this.errors = null;
    }
}
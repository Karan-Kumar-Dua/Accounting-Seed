import {api, LightningElement, track, wire} from 'lwc';
import { LabelService, KnowledgeBase, ErrorUtils } from 'c/utils';
import { Billing, PaymentProcessor, PaymentMethod } from 'c/sobject';
import Labels from "./labels";
import Helper from './paymentsReceiveHelper';
import getBillings from '@salesforce/apex/BillingsPaymentReceiveHelper.getBillings';
import getPaymentProcessors from '@salesforce/apex/BillingPaymentReceiveHelper.getPaymentProcessors';
import receivePayments from '@salesforce/apex/BillingsPaymentReceiveHelper.receivePayments';
import bankAccountsByLedgerIds from '@salesforce/apex/BillingsPaymentReceiveHelper.bankAccountsByLedgerIds';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

const MAX_BILLINGS_LOADED = 200;
const PAGE_SIZE = 10;
const CC_FLAT_FEE = 'CC Flat Fee';
const CC_PERCENT = 'CC Percent';
const CC_TYPE = 'Credit Card';
const ACH_TYPE = 'Bank Account';
const ACH_FLAT_FEE = 'ACH Flat Fee';
const ACH_PERCENT = 'ACH Percent';
const NONE = 'None';

const STRIPE_TYPE = 'Stripe';
const CARDKNOX_TYPE = 'Cardknox';
const CREDIT_CARD_METHOD_TYPE = 'Credit Card';
const BANK_METHOD_TYPE = 'Bank Account';
const PAYMENTS_BATCH_SIZE = 6;

export default class PaymentsReceive extends LightningElement {
    @api recordIds;

    @track billingLabelPlural;
    @track warningMessages = [];
    @track billings = [];
    @track showSpinner = true;

    pageSize = PAGE_SIZE;
    mainColumns = Helper.getMainColumns();
    additionalColumns = Helper.getAdditionalColumns();

    knowledgeBase = [
        {
            iconName: 'standard:question_feed',
            iconAltText: LabelService.KNOWLEDGE_BASE,
            url: KnowledgeBase.recievePayments
        }
    ];

    labels = { ...Labels, ...LabelService };
    processorsByCustomerIds = {};
    actions = {
        showRowActionsButtons: true,
        actions: [{label: LabelService.commonRemove, actionName: 'remove', isSkipValidation: true}]
    };
    changeNotifications = [
        {
            fieldApiName: 'selectedPP',
            eventName: 'processorchange'
        },
        {
            fieldApiName: 'includeConFee',
            eventName: 'includeconfeechange'
        },
        {
            fieldApiName: 'selectedPM',
            eventName: 'paymethodchange'
        },
    ];

    @track sortOpts = {
        sortedBy: 'customerName',
        sortedDirection: 'desc'
    };

    connectedCallback(){
        window.setTimeout(() => {
            document.title = this.labels.receivePayments;
          }, 200);
    }

    @wire(getObjectInfo, { objectApiName: Billing.objectApiName })
    fetchObjectInfo(result) {
        if (result && result.data) {
            this.billingLabelPlural = result.data.labelPlural;
        }
    }

    @wire(getBillings, {billingIds: '$recordIds', isAggregate: true})
    fetchBillings(result) {
        if (result.data) {
            this.billings = JSON.parse(result.data).map(billing => ({ ...billing, statusDetails: {}, isShowProcessorSpinner: true }));
            if (!this.billings?.length) {
                (this.showSpinner = false, this.setTableSpinner(false));
            } else {
                this.fetchPaymentProcessors([...new Set(this.billings.map(billing => billing.customerId))]);

            }
        }
        if (result.error) {
            this.processError(result.error);
            (this.showSpinner = false, this.setTableSpinner(false));
        }
    }

    handleCcData(){
        this.billings = [...this.billings.map(billing => {
            return this.ccDataProperties(billing);
        })]
    }

    ccDataProperties(billing){
        const processorsData = this.processorsByCustomerIds[billing.customerId];
                            const selectedPP = billing.selectedPP || processorsData?.selectedPPId;
                            const processorRecord = processorsData?.processorRecords?.find(record => record.Id === selectedPP);
                            const selectedPMInfo = billing?.paymentMethodsInfo?.find(record => record.AcctSeed__External_Id__c === billing?.selectedPM);
                            let isConFeeValid = false;
                            let confee = 0.0;
                            if(processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] !== NONE && selectedPMInfo[PaymentMethod.paymentMethodType.fieldApiName] === CC_TYPE &&
                                (
                                (processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_FLAT_FEE && processorRecord[PaymentProcessor.ccFlatFee.fieldApiName])
                                || processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_PERCENT && processorRecord[PaymentProcessor.ccPercent.fieldApiName]
                                )){
                                    isConFeeValid = true;
                                    confee =  processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_FLAT_FEE ?  processorRecord[PaymentProcessor.ccFlatFee.fieldApiName] : (parseFloat(billing.billingsBalance) * parseFloat(processorRecord[PaymentProcessor.ccPercent.fieldApiName]))/100;
                                }

                            if(processorRecord[PaymentProcessor.achFeeType.fieldApiName] !== NONE && selectedPMInfo[PaymentMethod.paymentMethodType.fieldApiName] === ACH_TYPE &&
                                (
                                (processorRecord[PaymentProcessor.achFeeType.fieldApiName] === ACH_FLAT_FEE && processorRecord[PaymentProcessor.achFlatFee.fieldApiName])
                                || (processorRecord[PaymentProcessor.achFeeType.fieldApiName] === ACH_PERCENT && processorRecord[PaymentProcessor.achPercent.fieldApiName])
                                )
                            )
                            {
                                isConFeeValid = true;
                                confee =  processorRecord[PaymentProcessor.achFeeType.fieldApiName] === ACH_FLAT_FEE ?  processorRecord[PaymentProcessor.achFlatFee.fieldApiName] : (parseFloat(billing.billingsBalance) * parseFloat(processorRecord[PaymentProcessor.achPercent.fieldApiName]))/100;
                            }


                            if(processorRecord[PaymentProcessor.enableConFee.fieldApiName] && processorRecord[PaymentProcessor.type.fieldApiName] == 'Cardknox' && isConFeeValid){
                                return {
                                    ...billing,
                                        feeGlAccount : processorRecord[PaymentProcessor.conFeeGLAccount.fieldApiName],
                                        convenienceFee : confee,
                                        includeConFee : true,
                                        disableIncludeFee : false,
                                        paymentAmount : parseFloat(billing.billingsBalance) + parseFloat(confee)
                            }
                            }
                                return {
                                    ...billing,
                                        feeGlAccount : null,
                                        convenienceFee : 0.0,
                                        includeConFee : false,
                                        disableIncludeFee : true,
                                        paymentAmount : parseFloat(billing.billingsBalance)
                            }
    }

    handleCcData(){
        this.billings = [...this.billings.map(billing => {
            return this.ccDataProperties(billing);
        })]
    }

    ccDataProperties(billing){
        const processorsData = this.processorsByCustomerIds[billing.customerId];
                            const selectedPP = billing.selectedPP || processorsData?.selectedPPId;
                            const processorRecord = processorsData?.processorRecords?.find(record => record.Id === selectedPP);
                            const selectedPMInfo = billing?.paymentMethodsInfo?.find(record => record.AcctSeed__External_Id__c === billing?.selectedPM);
                            let isConFeeValid = false;
                            let confee = 0.0;
                            if(processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] !== NONE && selectedPMInfo[PaymentMethod.paymentMethodType.fieldApiName] === CC_TYPE &&
                                (
                                (processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_FLAT_FEE && processorRecord[PaymentProcessor.ccFlatFee.fieldApiName])
                                || processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_PERCENT && processorRecord[PaymentProcessor.ccPercent.fieldApiName]
                                )){
                                    isConFeeValid = true;
                                    confee =  processorRecord[PaymentProcessor.creditCardFeeType.fieldApiName] === CC_FLAT_FEE ?  processorRecord[PaymentProcessor.ccFlatFee.fieldApiName] : (parseFloat(billing.billingsBalance) * parseFloat(processorRecord[PaymentProcessor.ccPercent.fieldApiName]))/100;
                                }

                            if(processorRecord[PaymentProcessor.achFeeType.fieldApiName] !== NONE && selectedPMInfo[PaymentMethod.paymentMethodType.fieldApiName] === ACH_TYPE &&
                                (
                                (processorRecord[PaymentProcessor.achFeeType.fieldApiName] === ACH_FLAT_FEE && processorRecord[PaymentProcessor.achFlatFee.fieldApiName])
                                || (processorRecord[PaymentProcessor.achFeeType.fieldApiName] === ACH_PERCENT && processorRecord[PaymentProcessor.achPercent.fieldApiName])
                                )
                            )
                            {
                                isConFeeValid = true;
                                confee =  processorRecord[PaymentProcessor.achFeeType.fieldApiName] === ACH_FLAT_FEE ?  processorRecord[PaymentProcessor.achFlatFee.fieldApiName] : (parseFloat(billing.billingsBalance) * parseFloat(processorRecord[PaymentProcessor.achPercent.fieldApiName]))/100;
                            }


                            if(processorRecord[PaymentProcessor.enableConFee.fieldApiName] && processorRecord[PaymentProcessor.type.fieldApiName] == 'Cardknox' && isConFeeValid){
                                return {
                                    ...billing,
                                        feeGlAccount : processorRecord[PaymentProcessor.conFeeGLAccount.fieldApiName],
                                        convenienceFee : confee,
                                        includeConFee : true,
                                        disableIncludeFee : false,
                                        paymentAmount : parseFloat(billing.billingsBalance) + parseFloat(confee)
                            }
                            }
                                return {
                                    ...billing,
                                        feeGlAccount : null,
                                        convenienceFee : 0.0,
                                        includeConFee : false,
                                        disableIncludeFee : true,
                                        paymentAmount : parseFloat(billing.billingsBalance)
                            }
    }

    @wire(bankAccountsByLedgerIds) bankAccountsByLedgerIds;

    get isBothModes() {
        const modes = [
            ...this.billings
                .map(billing => {
                    const processorsData = this.processorsByCustomerIds && this.processorsByCustomerIds[billing.customerId];
                    const processorRecord = processorsData?.processorRecords?.find(record => record.Id === billing.selectedPP);
                    return processorRecord && processorRecord[PaymentProcessor.testmode.fieldApiName];
                })
        ];
        return (new Set(modes)).size === 2;
    }

    get isCreatedSuccess() {
        return this.billings.filter(item => item.cashReceipt.obj.Id).length
            && !this.isBillingsItemError();
    }

    get isCreatedSuccessInfo() {
        return this.billings.filter(item => item.cashReceipt.obj.Id).length
            && this.isBillingsItemError();
    }

    get isHideReceivePayments() {
        return this.noQualifiedBillings || this.isCreatedSuccess || this.isBothModes || this.isError;
    }

    get maxInvoicesDisplayed() {
        return MAX_BILLINGS_LOADED;
    }

    get noQualifiedBillings() {
        return (!this.billings || !this.billings.length) && !this.showSpinner;
    }

    isBillingsItemError() {
        return this.billings.filter(item => item.errors && item.errors.length).length;
    }

    fetchPaymentProcessors(customerIds) {
        if (customerIds && customerIds.length) {
            const proms = customerIds.map(customerId => getPaymentProcessors({ customerId })
                            .then(result => 
                                {
                                    if(result.noDataAvailable === true && result.errorMessage !== ''){
                                        this.isError = true;
                                        this.error = [result.errorMessage];
                                    }
                                    this.processorsByCustomerIds[customerId] = result;
                                }));
            Promise.all(proms).finally(() => {
                this.billings = [
                    ...this.billings
                        .map(billing => {
                            const processorsData = this.processorsByCustomerIds[billing.customerId];
                            const selectedPP = billing.selectedPP || processorsData?.selectedPPId;
                            const processorRecord = processorsData?.processorRecords?.find(record => record.Id === selectedPP);
                            billing = this.presetProcessorBankAccount(billing, processorRecord);
                            return {
                                ...billing,
                                isShowProcessorSpinner: false,
                                availablePP: processorsData?.paymentProcessors,
                                selectedPP: processorsData?.selectedPPId,
                                availablePM: processorsData && processorsData.paymentMethodsWithProcessor && processorsData.paymentMethodsWithProcessor[selectedPP],
                                selectedPM: processorsData?.selectedPMId,
                                paymentMethodsInfo: processorsData?.paymentMethods,
                            }
                        })
                        .filter(billing => {
                            const processor = this.processorsByCustomerIds[billing.customerId];
                            return !processor || !processor.noDataAvailable;
                        })
                ];
                this.handleCcData();
                (this.showSpinner = false, this.setTableSpinner(false));
            });
        }
    }

    presetProcessorBankAccount(billing, processorRecord) {
        if (processorRecord && processorRecord[PaymentProcessor.type.fieldApiName] === this.labels.commonCardknox) {
            billing.cashReceipt.obj.AcctSeed__Bank_Account__c = processorRecord[PaymentProcessor.merchantGlAccount.fieldApiName];
            billing.merchantGlAccountName = processorRecord.AcctSeed__Merchant_GL_Account__r?.Name;

            billing.bankAccountFieldName = 'merchantGlAccountName';
            billing.bankAccountType = 'url';

            billing.bankAccountUrl = `/${processorRecord[PaymentProcessor.merchantGlAccount.fieldApiName]}`;
        } else {
            billing.cashReceipt.obj.AcctSeed__Bank_Account__c =
                (this.bankAccountsByLedgerIds?.data && this.bankAccountsByLedgerIds?.data[billing.ledgerId]?.id)
                || billing.cashReceipt.obj.AcctSeed__Bank_Account__c;

            billing.bankAccountFieldName = 'cashReceipt.obj.AcctSeed__Bank_Account__c';
            billing.bankAccountType = 'customLookup';
        }
        return billing;
    }

    handleProcessorChange({ detail }) {
        this.billings = [...this.billings.map(billing => {
            if (billing.Id === detail.id) {
                const processorsData = this.processorsByCustomerIds[billing.customerId];
                const processorRecord = processorsData?.processorRecords?.find(record => record.Id === detail.value);
                billing = this.presetProcessorBankAccount(billing, processorRecord);
                const paymentMethods = processorsData?.paymentMethodsWithProcessor[detail.value];
                return {
                    ...billing,
                    selectedPP: detail.value,
                    availablePM: paymentMethods,
                    selectedPM: paymentMethods && paymentMethods.length && paymentMethods[0].value,
                    paymentMethodsInfo: processorsData?.paymentMethods
                }
            }
                        return billing;
        })];
        this.handleCcData();
    }

    handlePaymentMethodChange({ detail }) {
        this.billings = [...this.billings.map(billing => {
            if (billing.Id === detail.id) {
                return {
                    ...billing,
                    selectedPM: detail.value,
                }
            }
                        return billing;
        })];
        this.handleCcData();
    }

    handleConFeeChange({ detail }){
        this.billings = [...this.billings.map(billing => {
            if (billing.Id === detail.id){
                if(!billing.disableIncludeFee && !detail.value) {
                    return {
                        ...billing,
                        includeConFee : detail.value,
                        paymentAmount : parseFloat(billing.billingsBalance),
                        convenienceFee : 0.0
                    }
                }else{
                    return this.ccDataProperties(billing)
                }
            }
            return billing;
        }
        )]
    }

    handleCancel() {
        window.history.back();
    }

    isTableValid() {
        return this.tableGridCmp()?.validateTable() && this.validateVirtualRows();
    }

    validateVirtualRows() {
        let isValid = true;
        const table = this.tableGridCmp();
        if (table) {
            const index = table.items.findIndex(wrap => !wrap?.cashReceipt?.obj?.AcctSeed__Bank_Account__c);
            if (~index) {
                isValid = false;
                table.goToPage(Math.floor(index/this.pageSize) + 1);
                this.nextPageValidation = {loadedRowIds: new Set([]), postLoadValidate: true};
            }
        }
        return isValid;
    }

    handleLoadCell({ detail }) {
        if (this.nextPageValidation?.postLoadValidate) {
            this.nextPageValidation.loadedRowIds.add(detail.id);
            if (this.nextPageValidation?.loadedRowIds?.size === this.pageSize) {
                this.tableGridCmp().validateTable();
            }
        }
    }

    filterByPaymentProcessorType(billings, paymentProcessorType, methodType) {
        return billings?.filter(billing => {
            const processorsData = this.processorsByCustomerIds[billing.customerId];
            const processorRecord = processorsData?.processorRecords?.find(record => record.Id === billing.selectedPP);
            const paymentMethodDetails = processorsData?.paymentMethodDetailsByExternalIds[billing.selectedPM];
            return processorRecord?.AcctSeed__Type__c === paymentProcessorType && paymentMethodDetails?.methodType === methodType;
        });
    }

    prepareBatches(billings) {
        const billingBatches = [];
        billings.forEach((billing, index, arr) => {
            !(index % PAYMENTS_BATCH_SIZE) && billingBatches.push([]);
            billingBatches[billingBatches.length - 1].push(billing);
        });
        return billingBatches;
    }

    handleReceivePayments() {
        if (this.isTableValid()) {
            this.setTableSpinner(true, true);
            this.billings = [...this.tableGridCmp().items.map(item => ({...item, isShowStatusSpinner: !item.isSuccess}))];
            const processingBillings = [...this.billings]
                .filter(billing => !billing.isSuccess)
                .map(billing => ({...billing, errors: []}));
            this.countProcessingBillings = processingBillings.length;
            const billingBatches = [
                ...this.prepareBatches(this.filterByPaymentProcessorType(processingBillings, STRIPE_TYPE, CREDIT_CARD_METHOD_TYPE)),
                ...this.prepareBatches(this.filterByPaymentProcessorType(processingBillings, STRIPE_TYPE, BANK_METHOD_TYPE)),
                ...this.prepareBatches(this.filterByPaymentProcessorType(processingBillings, CARDKNOX_TYPE, CREDIT_CARD_METHOD_TYPE)),
                ...this.prepareBatches(this.filterByPaymentProcessorType(processingBillings, CARDKNOX_TYPE, BANK_METHOD_TYPE))
            ];
            this.invokeReceivePayments(billingBatches);
        }
    }

    invokeReceivePayments(billings) {
        const leftCount = billings.reduce((accumulator, currentValue) => accumulator + currentValue?.length, 0)
        console.log('leftCount: ' + leftCount);
        this.resetProgressPercent(Math.round((this.countProcessingBillings - leftCount) * 100 / this.countProcessingBillings));
        if (billings?.length) {
            receivePayments({ serializedParams: JSON.stringify(billings.splice(0, 1)[0]) })
                .then(results => {
                    results.forEach(result => {
                        this.billings = [...this.billings.map(item => (
                            result.Id === item.Id ?
                                {
                                    ...item,
                                    ...result,
                                    errors: result.errors && result.errors.length ? result.errors : [],
                                    isSuccess: (!result.errors || !result.errors.length) && result?.cashReceipt?.obj?.Id,
                                    statusDetails: result?.cashReceipt?.obj?.Id
                                        ? { details: this.labels.commonSuccess, recordName: this.labels.commonViewRecord, recordURL:  '/' + result?.cashReceipt?.obj?.Id}
                                        : { details: this.labels.commonErrorText },
                                    isShowStatusSpinner: item.Id === result.Id ? false : item.isShowStatusSpinner
                                } : {...item}
                        ))];
                    })
                })
                .finally(() => this.invokeReceivePayments(billings));
        } else {
            this.setTableSpinner(false);
        }
    }

    handleItemsAction({detail}) {
        detail.action === 'remove' &&
        (
            this.setTableSpinner(false),
            this.removeBillingId = detail.data[0]?.Id,
            this.template.querySelector('[data-id="removeConfirm"]')?.openModal()
        );
    }

    closeModals() {
        this.template.querySelector('[data-id="removeConfirm"]')?.closeModal();
    }

    handleNo() {
        this.closeModals();
    }

    handleYes() {
        this.billings = [...this.billings.filter(billing => billing.Id !== this.removeBillingId)];
        this.closeModals();
    }

    handleSortOpt({ detail }) {

    }

    handlePageSelect({ detail }) {

    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    setTableSpinner(isShown, isProgress) {
        let element = this.tableGridCmp();
        if (element) {
            element.showTableSpinner(isShown, isProgress);
        }
    }

    resetProgressPercent(value) {
        let element = this.tableGridCmp();
        if (element) {
            element.resetProgressPercent(value);
        }
    }

    tableGridCmp = () => this.template.querySelector(".billings-table");
}
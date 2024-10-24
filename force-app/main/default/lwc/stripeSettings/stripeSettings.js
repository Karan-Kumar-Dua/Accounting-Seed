import { wire, track} from 'lwc';
import { LabelService, NavigationService, NotificationService, RecordProxy, KnowledgeBase, CommonUtils } from 'c/utils';
import {AccountingSettings, PaymentProcessor, Ledger} from 'c/sobject';
import AP_PAYMENT_PROCESSOR from '@salesforce/schema/Payment_Processor__c.AP_Payment_Processor__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { updateRecord } from 'lightning/uiRecordApi';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import getPaymentLinkAuthorizationUrl from '@salesforce/apex/AccountingSettingsHelper.getPaymentLinkAuthrizationURL';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import PAYMENT_PROCESSOR_OBJECT from '@salesforce/schema/Payment_Processor__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import { keywords } from "c/lookupKeywords";

const EDIT_MODE = {id: 'EDIT_MODE'};
const VIEW_MODE = {id: 'VIEW_MODE'};

export default class StripeSettings extends NavigationService {
    /**
     * Expose labels to the UI
     */
    labels = LabelService;
    ledger = Ledger;
    paymentProcessor = PaymentProcessor;
    currentMode = {...VIEW_MODE};
    paymentProcessorPluralLabel = 'Payment Processors';
    paymentProcessorListviewURL = '/#';
    paymentProcessorWarnStart = LabelService.stripeSettingsMoved.split('{0}')[0];
    paymentProcessorWarnEnd = LabelService.stripeSettingsMoved.split('{0}')[1];

    paymentProcessorFields = [
        PaymentProcessor.nameField
    ];

    paymentProcessorFilter =  {
        [keywords.logical.AND] : [
            {field: PaymentProcessor.active.fieldApiName,
                op: keywords.op.EQUAL,
                val: true,
                type: keywords.type.BOOLEAN},
            {field: AP_PAYMENT_PROCESSOR.fieldApiName,
                op: keywords.op.EQUAL,
                val: false,
                type: keywords.type.BOOLEAN}]
    };

    isShowSpinner = true;

    @wire (getObjectInfo, { objectApiName: PAYMENT_PROCESSOR_OBJECT })
    getPaymentProcessorInfo({ err, data}) {
        if (err) {
            console.error(err);
        }
        if (data) {
            this.paymentProcessorPluralLabel = data.labelPlural;
            this.getNavigationUrlListview(PAYMENT_PROCESSOR_OBJECT.objectApiName).then(url => {
                this.paymentProcessorListviewURL = url;
            });
        }
    }

    /**
     * Quick access to field labels instead of storing
     * these as custom labels.
     */
    @wire (getObjectInfo, { objectApiName: ACCOUNTING_SETTINGS_OBJECT })
    getAccountingSettingsInfo({ err, data}) {
        if (err) {
            console.error(err);
        }
        if (data) {
            this.accountingSettingsInfo = new RecordProxy(data);

            // retrieve settings record once we can proxy it
            getSettings()
            .then((res) => {
                this.stripeConnectedAccountId = res && res[AccountingSettings.stripeConnectedAccountId.fieldApiName];
                this.accountingSettings = this.accountingSettingsInfo.getRecord(res);
                this.paymentProcessorLookupId = this.accountingSettings.Default_Payment_Services_Ledger__c;
   
            })
            .catch((err) => {
                console.log(err);
            })
            .finally(() => {
                this.isShowSpinner = false;
            });
        }
    }

    @wire (getPaymentLinkAuthorizationUrl)
    paymentLink;

    @track
    accountingSettingsInfo;

    @track
    accountingSettings;

    @track
    stripeConnectedAccountId;

    @track
    paymentProcessorLookupId;

    get isEditable() {
        return this.currentMode.id === EDIT_MODE.id;
    }

    /**
     * Page header navigation
     */
    get breadcrumbs () {
        return [
            { title: LabelService.commonAccountingHome,
                tab: `${this.accountingSettingsInfo?.namespace || CommonUtils.getPackageQualifier(ACCOUNTING_SETTINGS_OBJECT.objectApiName)}Accounting_Home2`},
            { title: LabelService.accountingSetup }
        ];
    }

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        { 
            iconName: 'standard:question_feed', 
            iconAltText: 'Knowledge Base',
            url: KnowledgeBase.stripeSettings
        }
    ];
    
    /**
     * Permission checks for UI elements
     */

    get userCanView() {
        // write gives implicit read permission
        return HAS_READ_PERMISSION || HAS_EDIT_PERMISSION;
    }

    get userCanEdit () {
        return HAS_EDIT_PERMISSION;
    }

    get userCannotEdit () {
        return !HAS_EDIT_PERMISSION;
    }

    get isLoaded () {
        return this.accountingSettings && this.accountingSettingsInfo;
    }

    /**
     * Disable input fields when in read mode.
     */
    get isDisabled () {
        return (this.currentMode.id !== EDIT_MODE.id) || !HAS_EDIT_PERMISSION;
    }

    get paymentLinkBtnLabel () {
        return this.accountingSettings && this.accountingSettings.Payment_Link_Username__c 
            ? this.labels.stripeSettingsReconfigureButton
            : this.labels.stripeSettingsConfigureButton;
    }

    /**
     * Authorize PaymentLink
     */
    handleConfigurePayment () {
        if (this.paymentLink.data) {
            this.navigateToWebPage(this.paymentLink.data, false);
        } else if (this.paymentLink.error) {
            NotificationService.displayToastMessage(
                this,
                LabelService.stripeSettingsPaymentLinkError,
                LabelService.commonToastErrorTitle,
                'error'
            );
        }
    }

    handleSave() {
        const paymentProcessorLookup = this.template.querySelector('[data-id="lookup-stripeSettings"]');
        const paymentProcessorId = paymentProcessorLookup && paymentProcessorLookup.selection &&
            paymentProcessorLookup.selection[0] && paymentProcessorLookup.selection[0].id;


        const paymentServiceLedgerLookup = this.template.querySelector('[data-id="lookup-defaultPaymentServicesledger"]');
        const paymentServiceLedgerLookupId = paymentServiceLedgerLookup && paymentServiceLedgerLookup.selection &&
                            paymentServiceLedgerLookup.selection[0] && paymentServiceLedgerLookup.selection[0].id;


        const CDSetToApprovedForPPValue= this.template.querySelector('[data-id="lightningInput-CDSetToApprovedForPaymentProposals"]').checked;
        const fields = {
            Id: this.accountingSettings.Id,
            [AccountingSettings.stripeConnectedAccountId.fieldApiName]: paymentProcessorId || '',
            [this.accountingSettingsInfo.fields.Default_Payment_Services_Ledger__c.apiName] : paymentServiceLedgerLookupId,
            [this.accountingSettingsInfo.fields.CD_Set_to_Approved_for_Payment_Proposals__c.apiName]: CDSetToApprovedForPPValue

        };

        this.isShowSpinner = true;
        updateRecord({ fields })
            .then((result) => {
                this.notifySuccess();
                this.stripeConnectedAccountId = paymentProcessorId;
                this.paymentProcessorLookupId = paymentServiceLedgerLookupId;
                this.currentMode = {...VIEW_MODE};
            })
            .catch(error => {
                this.notifyError(error);
            })
            .finally(() => {
                this.isShowSpinner = false;
            });
    }

    notifySuccess() {
        NotificationService.displayToastMessage(
            this,
            LabelService.paymentSettingsSuccess,
            LabelService.commonToastSuccessTitle,
            'success'
        );
    }
    
    notifyError(error) {
        NotificationService.displayToastMessage(
            this,
            error.body.message,
            LabelService.commonToastErrorTitle,
            'error'
        );
    }

    handleEdit() {
        this.currentMode = {...EDIT_MODE};
    }

    handleCancel() {
        this.currentMode = {...VIEW_MODE};
    }
}
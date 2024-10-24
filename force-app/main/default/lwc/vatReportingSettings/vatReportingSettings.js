import { wire, track} from 'lwc';
import {NavigationMixin} from "lightning/navigation";
import {CommonUtils, LabelService, NavigationService, NotificationService, RecordProxy, ErrorUtils, Constants} from 'c/utils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import saveSettings from '@salesforce/apex/AccountingSettingsHelper.save';
import saveLedgers from '@salesforce/apex/AccountingSettingsHelper.saveLedgers';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';
import getAvaVATEndpointOptions from '@salesforce/apex/AccountingSettingsHelper.getAvaVATEndpointOptions';
import getAvaVATLedgerCountryOptions from '@salesforce/apex/AccountingSettingsHelper.getAvaVATLedgerCountryOptions';
import getLedgers from '@salesforce/apex/AccountingSettingsHelper.getTransactionalLedgers';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import GL_ACCOUNT_OBJECT from '@salesforce/schema/GL_Account__c';
import LEDGER_OBJECT from '@salesforce/schema/Ledger__c';
import GL_ACCOUNT_NAME_FIELD from '@salesforce/schema/GL_Account__c.Name';
import GL_ACCOUNT_TYPE_FIELD from '@salesforce/schema/GL_Account__c.Type__c';
import PDF_FORMAT_OBJECT from '@salesforce/schema/Billing_Format__c';
import PDF_FORMAT_NAME_FIELD from '@salesforce/schema/Billing_Format__c.Name';
import PDF_FORMAT_TYPE_FIELD from '@salesforce/schema/Billing_Format__c.Type__c';
import PDF_FORMAT_VFPAGE_FIELD from '@salesforce/schema/Billing_Format__c.Visualforce_PDF_Page__c';
import PDF_FORMAT_EMAILTEMPLATE_FIELD from '@salesforce/schema/Billing_Format__c.Default_Email_Template__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import {keywords} from 'c/lookupKeywords';
import {BillingFormat, GlAccount} from "c/sobject";
import Labels from './labels';

import TAX_SETTINGS_OBJECT from '@salesforce/schema/Tax_Settings__c';

export default class VatReportingSettings extends NavigationService {

    labels = {...Labels, ...LabelService};
    @wire (getObjectInfo, { objectApiName: LEDGER_OBJECT })
    objectInfo({err, data}) {
        if (err) {
            console.error(err);
        }
        if (data) {
            this.ledgerInfo = new RecordProxy(data);
            this.prepareLedgers();
        }
    }

    @wire (getLedgers)
    ledgerData(result) {
        this.rawLedgers = result;
        if (this.rawLedgers.error) {
            console.error(error);
        }
        if (this.rawLedgers.data) {
            this.prepareLedgers();
        }
    }

    prepareLedgers() {
        if (this.ledgerInfo && this.rawLedgers?.data) {
            this.ledgers = this.ledgerInfo.getRecords(this.rawLedgers.data);
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
            this.prepareAccountingSettings();
        }
    }

    @wire (getSettings)
    fetchSettings(result) {
        this.rawAccountingSettings = result;
        if (this.rawAccountingSettings.data) {
            this.prepareAccountingSettings();
        }
        if (this.rawAccountingSettings.error) {
            console.error(this.rawAccountingSettings.error);
        }
    }

    prepareAccountingSettings() {
        if (this.accountingSettingsInfo && this.rawAccountingSettings.data) {
            this.showSpinner = false
            this.accountingSettings = this.accountingSettingsInfo.getRecord(this.rawAccountingSettings.data);
        }
    }

    @wire (getConfigs)
    configs;

    connectedCallback() {
        this.proxyNavigation(this[NavigationMixin.GenerateUrl])
            .navigateToPinnedListView(TAX_SETTINGS_OBJECT.objectApiName)
            .then(url => this.taxSettingsHref = url);
    }

    @wire (getAvaVATLedgerCountryOptions)
    ledgersVatCountry;

    @wire (getAvaVATEndpointOptions)
    avaVATEndpointOptions;

    @track
    accountingSettingsInfo;

    @track
    accountingSettings;

    @track
    accountingSettingsProxy = {};

    selectedTaxCalculationType;

    @track
    ledgerInfo;

    @track
    ledgers;

    @track
    taxSettingsHref;

    pdfFormatFields = [
        PDF_FORMAT_NAME_FIELD,
        PDF_FORMAT_TYPE_FIELD,
        PDF_FORMAT_VFPAGE_FIELD,
        PDF_FORMAT_EMAILTEMPLATE_FIELD
    ];

    refreshRadioButton = true;

    /**
     * Page header navigation
     */
    get breadcrumbs () {
        return [
            { title: LabelService.commonAccountingHome,
                tab: `${this.accountingSettingsInfo?.namespace || CommonUtils.getPackageQualifier(ACCOUNTING_SETTINGS_OBJECT.objectApiName)}Accounting_Home2` },
            { title: LabelService.accountingSetup }
        ];
    }

    get glAccountApiName () {
        return GL_ACCOUNT_OBJECT.objectApiName;
    }

    get pdfFormatObject () {
        return PDF_FORMAT_OBJECT.objectApiName;
    }

    /**
     * Edit mode on/off
     */
    isEditable = false;

    isLedgerEditable = false;

    /**
     * Used to display record details in
     * lookup popovers.
     */
    glAccountFields = [
        GL_ACCOUNT_NAME_FIELD,
        GL_ACCOUNT_TYPE_FIELD
    ];

    ledgerConfigurationSearchFilters = {
        defaultBankAccount: {
            type: keywords.type.BOOLEAN,
            field: GlAccount.bank.fieldApiName,
            op: keywords.op.EQUAL,
            val: true
        },
        defaultBillingFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_BILLING
        },
        billingActivityStatementFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_ACTIVITY_STATEMENT
        },
        billingOutstandingStatementFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_OUTSTANDING_STATEMENT
        }
    };

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        {
            iconName: 'standard:question_feed',
            iconAltText: 'Knowledge Base',
            url: 'https://support.accountingseed.com/hc/en-us/articles/4412652062739'
        }
    ];

    /**
     * Expose labels to the UI
     */

    get avalaraVatEndpointType() {
        return this.accountingSettings && this.accountingSettings.Avalara_VAT_Reporting_Endpoint__c.toString();
    }

    get isAvalaraVatEndpoint() {
        return this.avaVATEndpointOptions.data && this.refreshRadioButton;
    }

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

    /**
     * Disable input fields when in read mode.
     */
    get isDisabled () {
        return !this.isEditable || !HAS_EDIT_PERMISSION;
    }

    get isLedgerDisabled () {
        return !this.isLedgerEditable || !HAS_EDIT_PERMISSION;
    }

    /**
     * Page has all its necessary data
     */
    get isLoaded () {
        return this.accountingSettings && this.accountingSettingsInfo;
    }

    /**
     * Display options
     */
    get isAvalaraVAT () {
        return this.configs.data && this.configs.data.pkgs.avaVAT.installed;
    }

    handleLedgerEdit () {
        this.isLedgerEditable = true;
    }

    handleLedgerCancel () {
        this.isLedgerEditable = false;
        let fields = [...this.template.querySelectorAll('[data-ledgerfield]')];
        fields.forEach((field) => {
            field.value = this.ledgers[field.dataset.index][field.dataset.ledgerfield];
        });
    }

    handleLedgerSave () {
        this.isLedgerEditable = false;

        // deep clone of ledger data
        let ledgerUpdates = JSON.parse(JSON.stringify(this.ledgers));

        let lookups = [...this.template.querySelectorAll('[data-lookupledger]')];
        lookups.forEach((lookup) => {
            let selections = lookup.getSelection();
            if (selections.length) {
                ledgerUpdates[lookup.dataset.index][lookup.dataset.lookupledger] = selections[0].id;
            }
        });

        let fields = [...this.template.querySelectorAll('[data-ledgerfield]')];
        fields.forEach((field) => {
            ledgerUpdates[field.dataset.index][field.dataset.ledgerfield] = field.value;
        });

        saveLedgers({
            ledgers: this.ledgerInfo.getSObjects(ledgerUpdates)
        }).then((res) => {
            NotificationService.displayToastMessage(
                this,
                LabelService.multiLedgerDefaultsSuccess,
                LabelService.commonSuccess,
                'success'
            );
        }).catch((err) => {
            NotificationService.displayToastMessage(
                this,
                LabelService.multiLedgerDefaultsError,
                LabelService.commonToastErrorTitle,
                'error'
            );
        }).finally(() => {
            refreshApex(this.rawLedgers);
        });
    }

    handleEdit () {
        this.isEditable = true;
    }

    handleCancel () {
        this.isEditable = false;
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            field.value = this.accountingSettings[field.dataset.field];
        });
        this.selectedTaxCalculationType = this.taxCalculationType
        this.refreshRadioButton = false;
        setTimeout(() => {this.refreshRadioButton = true}, 0);
    }

    handleSave () {
        const settings = { ...this.accountingSettings };
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            settings[field.dataset.field] = field.value;
        });
        Object.keys(this.accountingSettingsProxy).forEach((field) => {
            settings[field] = this.accountingSettingsProxy[field];
        });

        saveSettings({
            settings: this.accountingSettingsInfo.getSObject(settings)
        }).then((res) => {
            this.isEditable = false;
            NotificationService.displayToastMessage(
                this,
                LabelService.commonSaveSuccessful, // @todo replace
                LabelService.commonSuccess,
                'success'
            );
        }).catch((err) => {
            const {error} = ErrorUtils.processError(err);
            NotificationService.displayToastMessage(
                this,
                error,
                'Error',
                'error'
            );
        }).finally(() => {
            refreshApex(this.rawAccountingSettings);
        });
    }

    handleVatEndpointOptionChange (evt) {
        this.accountingSettingsProxy.Avalara_VAT_Reporting_Endpoint__c = evt.target.value === "true";
    }
}
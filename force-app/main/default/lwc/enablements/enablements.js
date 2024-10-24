import { LightningElement, track, wire} from 'lwc';
import { LabelService, NotificationService, RecordProxy, CommonUtils, KnowledgeBase } from 'c/utils';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { keywords } from 'c/lookupKeywords';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import saveSettings from '@salesforce/apex/AccountingSettingsHelper.save';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import CREDIT_MEMO_DEFAULTS_FIELD from '@salesforce/schema/Accounting_Settings__c.Credit_Memo_Default__c';
import CASH_DISBURSEMENT_SOURCE_FIELD from '@salesforce/schema/Accounting_Settings__c.Cash_Disbursement_Source__c';

import GL_ACCOUNT_OBJECT from '@salesforce/schema/GL_Account__c';
import GL_ACCOUNT_NAME_FIELD from '@salesforce/schema/GL_Account__c.Name';
import GL_ACCOUNT_TYPE_FIELD from '@salesforce/schema/GL_Account__c.Type__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';

export default class Enablements extends LightningElement {

    /**
     * Expose labels to the UI
     */
    labels = LabelService;
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
    getAccountingSettings ({ err, data}) {
        if (err) {
            console.error(err);
        }
        if (data && (HAS_READ_PERMISSION || HAS_EDIT_PERMISSION)) {
            this.rawAccountingSettings = data;
            this.prepareAccountingSettings();
        }
    }

    @wire (getConfigs)
    configs;

    /**
     * Credit memo defaults picklist options for radio buttons
     */
    @wire (getPicklistValues, { 
        recordTypeId: '$accountingSettingsInfo.schema.defaultRecordTypeId',
        fieldApiName: CREDIT_MEMO_DEFAULTS_FIELD
    }) 
    creditMemoDefaults;

    @wire (getPicklistValues, { 
        recordTypeId: '$accountingSettingsInfo.schema.defaultRecordTypeId',
        fieldApiName: CASH_DISBURSEMENT_SOURCE_FIELD
    }) 
    cashDisbursementSource;


    @track
    accountingSettings;

    @track
    accountingSettingsInfo;

    rawAccountingSettings

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
     * Used to display record details in
     * lookup popovers.
     */
    glAccountFields = [
        GL_ACCOUNT_NAME_FIELD,
        GL_ACCOUNT_TYPE_FIELD
    ];

    /**
     * Filter GL Accounts by type = 'Cash Flow'
     * for cash flow lookups
     */
    glAccountFilter = {
        field: GL_ACCOUNT_TYPE_FIELD.fieldApiName,
        op: keywords.op.EQUAL,
        val: 'Cash Flow',
        type: keywords.type.STRING
    };

    /**
     * Edit mode on/off
     */
    isEditable = false;

    isModalOpen = false;

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        { 
            iconName: 'standard:question_feed', 
            iconAltText: LabelService.knowledgeBase,
            url: KnowledgeBase.enablements
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

    /**
     * Disable input fields when in read mode.
     */
    get isDisabled () {
        return !this.isEditable || !HAS_EDIT_PERMISSION;
    }

    get isLoaded () {
        return this.accountingSettings && this.accountingSettingsInfo;
    }

    get isMultiCurrencyEnabled () {
        return this.configs.data && this.configs.data.enablements.multiCurrencyEnabled;
    }

    get isCashFlowDisabled () {
        return this.isDisabled ||
            (this.accountingSettings &&
            this.accountingSettings.Enable_Cash_Flow_Statement__c)
    }

    get isERPEnabled () {
        return this.configs?.data?.pkgs?.erp?.installed;
    }


    get glAccountApiName () {
        return GL_ACCOUNT_OBJECT.objectApiName;
    }

    /**
     * Enables edit mode for the auto-post settings section.
     */
    handleEdit () {
        this.isEditable = true;
    }

    /**
     * Discard changes to auto-post settings.
     */
    handleCancel () {
        this.isEditable = false;
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            let value = this.accountingSettings[field.dataset.field];
            if (field.type == 'toggle') {
                field.checked = value;
            } else {
                field.value = value;
            }
        });

        // Lookups are a custom component and must be handled differently
        let lookups = [...this.template.querySelectorAll('[data-lookup]')];
        lookups.forEach((lookup) => {
            lookup.initValue = this.accountingSettings[lookup.dataset.lookup];
        });
    }

    /**
     * Save auto-post settings.
     */
    handleSave () {
        this.isEditable = false;

        const settings = {...this.accountingSettings};
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            settings[field.dataset.field] = CommonUtils.getFieldValue(field);
        });

        // Lookups are a custom component and must be handled differently
        let lookups = [...this.template.querySelectorAll('[data-lookup]')];
        lookups.forEach((lookup) => {
            let selection = lookup.getSelection();
            settings[lookup.dataset.lookup] = (
                selection.length ?
                selection[0].id :
                null
            );
        });

        // re-namespace
        const nsSettings = this.accountingSettingsInfo.getSObject(settings);

        saveSettings({
            settings: nsSettings
        }).then((res) => {
            NotificationService.displayToastMessage(
                this,
                LabelService.commonSaveSuccess,
                LabelService.commonSuccess,
                'success'
            );

            // setting this manually to kick the popovers
            // into updating
            this.accountingSettings = settings;
        }).catch((err) => {
            console.error(err)
            NotificationService.displayToastMessage(
                this,
                err.body.message,
                LabelService.commonToastErrorTitle,
                'error'
            );
        });
    }

    /**
     * When the enable cash flow statement field
     * is changed, if the toggle is checked, display
     * an informational modal.
     */
    handleCashFlowStatementChange (evt) {
        if (evt.target.checked) {
            this.isModalOpen = true;
        };
    }

    /**
     * If the modal is cancelled, do not enable
     * cash flow statement.
     */
    handleCloseModal () {
        this.template
            .querySelector('[data-id="lightningInput-cashFlowStatement"]')
            .checked = false;
        this.isModalOpen = false;
    }

    /**
     * Submitting the modal just closes it -
     * server actions are performed on save.
     */
    handleSubmitModal () {
        this.isModalOpen = false;
    }

    prepareAccountingSettings() {
        if (this.accountingSettingsInfo && this.rawAccountingSettings) {
            this.accountingSettings = this.accountingSettingsInfo.getRecord(this.rawAccountingSettings);
        }
    }
    
}
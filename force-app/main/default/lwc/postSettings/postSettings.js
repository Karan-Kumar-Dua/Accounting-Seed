import { LightningElement, wire, track} from 'lwc';
import { LabelService, NotificationService, RecordProxy, KnowledgeBase, CommonUtils } from 'c/utils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import saveSettings from '@salesforce/apex/AccountingSettingsHelper.save';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import POST_SETTINGS_FIELD from '@salesforce/schema/Accounting_Settings__c.Post_Settings__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';

export default class PostSettings extends LightningElement {

    /**
     * Expose labels to the UI
     */
    labels = LabelService;

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
    getAccountingSettings ({ err, data}) {
        if (err) {
            console.error(err);
        }
        if (data && (HAS_READ_PERMISSION || HAS_EDIT_PERMISSION)) {
            this.accountingSettingsData = data;
            this.prepareAccountingSettings();
        }
    }

    prepareAccountingSettings() {
        if (this.accountingSettingsInfo && this.accountingSettingsData) {
            this.accountingSettings = this.accountingSettingsInfo.getRecord(this.accountingSettingsData);
        }
    }

    @wire (getConfigs)
    configs;

    @track
    accountingSettingsInfo;

    @track
    accountingSettings

    /**
     * Internal state tracking for Auto Post Source Documents.
     * This is used to determine what text to display in the modal;
     * values for saving are read from the toggle itself.
     */
    @track
    autoPost;

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
            iconAltText: LabelService.commonKnowledgeBase,
            url: KnowledgeBase.postSettings
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
        return !this.isEditable || !HAS_EDIT_PERMISSION;
    }

    /**
     * Modal message should change if ERP is installed.
     * This is a rich text custom label.
     */
    get autoPostOffMessage () {
        return (
            this.configs.data && this.configs.data.pkgs.erp.installed ?
            LabelService.postSettingsAutoOffMsgExt :
            LabelService.postSettingsAutoOffMsg
        );
    }

    get autoPostOnMessage () {
        return (
            this.configs.data && this.configs.data.pkgs.erp.installed ? 
            LabelService.postSettingsAutoOnMsgExt :
            LabelService.postSettingsAutoOnMsg
        )
    }

    get isShowInventoryMovements() {
        return this.isLoaded && this.configs.data && this.configs.data.pkgs.erp.installed;
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
            field.checked = this.accountingSettings[field.dataset.field];
        });
    }

    /**
     * Save auto-post settings.
     */
    handleSave () {
        this.isEditable = false;
        let fields = [...this.template.querySelectorAll('[data-field]')];
        let settings = Object.assign({}, this.accountingSettings);

        fields.forEach((field) => {
            settings[field.dataset.field] = field.checked;
        });

        // Re-namespace
        settings = this.accountingSettingsInfo.getSObject(settings);

        saveSettings({
            settings: settings
        }).then((res) => {
            NotificationService.displayToastMessage(
                this,
                LabelService.commonSaveSuccess,
                LabelService.commonSuccess,
                'success'
            );
        }).catch((err) => {
            NotificationService.displayToastMessage(
                this,
                err,
                LabelService.commonToastErrorTitle,
                'error'
            );
        }).finally(() => {
            refreshApex(this.accountingSettings);
        });
    }

    /**
     * Display the modal when auto post value changes.
     * Modal is informational only.
     */
    handlePostSettingsChanged (evt) {
        this.autoPost = evt.target.checked;
        this.selectedAutoPostField = evt.target.dataset.field;
        this.isModalOpen = true;
    }

    /**
     * If cancelling out of the modal, return auto post to
     * previous value. Submitting persists the value in the UI.
     */
    handleCloseModal () {
        this.isModalOpen = false;
        this.autoPost = !this.autoPost;
        let selector = `[data-field=${this.selectedAutoPostField}]`;
        this.template
            .querySelector(selector)
            .checked = this.autoPost;
    }

    /**
     * Settings are updated on save, this modal
     * is purely informational.
     */
    handleSubmitModal () {
        this.isModalOpen = false;
    }
    
}
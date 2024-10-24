import { LightningElement, wire, track } from 'lwc';
import { CommonUtils, NotificationService, LabelService, RecordProxy, KnowledgeBase } from 'c/utils';
import { AccountingSettings } from 'c/sobject';
import { refreshApex } from '@salesforce/apex';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import run from '@salesforce/apex/AutomatedJobsHelper.run';
import schedule from '@salesforce/apex/AutomatedJobsHelper.schedule';
import remove from '@salesforce/apex/AutomatedJobsHelper.remove';
import getAvailableJobs from '@salesforce/apex/AutomatedJobsHelper.getAvailableJobs';
import getSchedule from '@salesforce/apex/AutomatedJobsHelper.getSchedule';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';
import saveSettings from '@salesforce/apex/AccountingSettingsHelper.saveWithAJRRetentionJobTime';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import AutomatedJobsSchdPost from 'c/automatedJobsSchdPost';
import Labels from './labels';

const SCHEDULED_POST_JOB = 'Scheduled Post';

/**
 * Component representing the automated jobs page within
 * Accounting Settings. Responsible for scheduling new automated
 * jobs, managing existing ones, running ad-hoc jobs, and
 * managing email notifications and job records.
 */
export default class AutomatedJobs extends LightningElement {

    labels = {...Labels, ...LabelService};
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

    /**
     * A list of job types in combobox format.
     * Contains additional flags for on demand and scheduled jobs
     * for ease of filtering.
     */
    @wire (getAvailableJobs)
    availableJobs;

    /**
     * Full Accounting_Settings__c record
     */
    @wire (getSettings)
    getAccountingSettings ({err, data}) {
        if (err) {
            console.error(err);
        }
        if (data && (HAS_READ_PERMISSION || HAS_EDIT_PERMISSION)) {
            this.accountingSettingsData = data;
            this.prepareAccountingSettings();
        }
    }

    @wire (getConfigs)
    configs;

    @track scheduledPostTypeState;

    @track selectedSchdTypes;

    @track timesToExclude;

    @track accountingSettings;

    accountSettingsData;

    /**
     * Edit mode on/off
     */
    isEditable = false;

    /**
     * Currently scheduled; refreshed via `refreshSchedule`
     */
    scheduledJobs = [];

    /**
     * State management for input fields
     */
    jobToSchedule;

    @track jobToScheduleTime = '0';

    @track isHideSelectScheduledPostTypeModal = false;

    get selectedSchdTypesToString() {
        return this.scheduledPostTypeState && this.scheduledPostTypeState.selectedSchdTypes &&
            this.scheduledPostTypeState.selectedSchdTypes.join(', ');
    }

    showSpinner = false;

    jobToRun;

    jobToRemove;

    /**
     * State management for modal
     */
    isModalOpen = false;

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

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        { 
            iconName: 'standard:question_feed', 
            iconAltText: LabelService.knowledgeBase,
            url: KnowledgeBase.automatedJobs
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

    get startTimes () {
        this._startTimes || (this._startTimes = CommonUtils.startTimes(this.timesToExclude));
        return this._startTimes;
    }
    set startTimes (value) {
        this._startTimes = value;
    }

    get deletionStartTimes () {
        return CommonUtils.startTimes();
    }

    /**
     * Filters available jobs to only show those
     * which can be run on demand.
     */
    get onDemandJobs () {
        return (
            this.availableJobs.data ?
            this.availableJobs.data.filter(job => job.onDemand) :
            [] // availableJobs hasn't loaded yet
        );
    }

    get selectScheduledPostTypeModalClasses() {
        return this.isHideSelectScheduledPostTypeModal && CommonUtils.computeClasses(['slds-hide']);
    }
    

    /**
     * Get newest scheduled jobs records and update
     * the UI table.
     */
    refreshSchedule (callback) {
        return getSchedule()
            .then((res) => {
                this.scheduledJobs = res;
            })
            .finally(() => {callback && callback.finally && callback.finally()});
    }

    resetJobToScheduleTime() {
        this.startTimes = CommonUtils.startTimes(this.jobToSchedule === SCHEDULED_POST_JOB ? this.timesToExclude : []);
        this.startTimes.find(item => item.value === this.jobToScheduleTime) ||
            (this.jobToScheduleTime = this.startTimes[0] && this.startTimes[0].value);
    }

    getExcludedTimeValues() {
        let timeValues = [];
        if (this.scheduledJobs && this.scheduledJobs.length > 0) {
            for (const job of this.scheduledJobs) {
                if (job.jobType.includes(SCHEDULED_POST_JOB)) {
                    timeValues.push(job.preferredStartTime);
                }
            }
        }
        this.timesToExclude = timeValues;
    }

    /**
     * Schedule a new job by selecting the job type
     * and a time for that job to run.
     */
    addScheduledJob () {
        let valid = this.template
            .querySelector('[data-id="lightningCombobox-scheduledJob"]')
            .reportValidity();

        if (valid) {
            this.showSpinner = true;
            schedule({
                jobName: this.jobToSchedule,
                startTime: this.jobToScheduleTime,
                schdPostTypes: this.scheduledPostTypeState && this.scheduledPostTypeState.selectedSchdTypes
            }).then(() => {
                NotificationService.displayToastMessage(
                    this,
                    LabelService.jobScheduledSuccess,
                    LabelService.commonSuccess,
                    'success'
                );
            }).catch((err) => {
                console.error(err);
            }).finally(() => {
                this.showSpinner = false;
                this.refreshSchedule({finally: () => {
                    this.getExcludedTimeValues();
                    this.resetJobToScheduleTime();
                }});
            });
        }
    }
    handleAddScheduledJob () {
        switch (this.jobToSchedule) {
            case SCHEDULED_POST_JOB: {
                this.getExcludedTimeValues();
                this.resetJobToScheduleTime();
                this.openScheduledPostTypeModal({
                    ...AutomatedJobsSchdPost.ADD_SCHD_JOBS_STATE,
                    jobToScheduleTime: this.jobToScheduleTime
                });
                break;
            }
            default: this.addScheduledJob()
        }
    }

    /**
     * Run a job on-demand by selecting the job and
     * clicking a start button.
     */
    runNow () {
        let valid = this.template
            .querySelector('[data-id="lightningCombobox-runJob"]')
            .reportValidity();

        if (valid) {
            this.showSpinner = true;
            run({
                jobName: this.jobToRun,
                schdPostTypes: this.scheduledPostTypeState && this.scheduledPostTypeState.selectedSchdTypes
            }).then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    res,
                    LabelService.commonSuccess,
                    'success'
                );
            }).catch((err) => {
                const msg = err?.body?.message || err.statusText + ': ' + err.status;
                NotificationService.displayToastMessage(
                    this,
                    msg,
                    LabelService.commonError,
                    'error'
                );
                console.error(err);
            }).finally(() => {
                this.showSpinner = false;
            });
        }
    }
    handleRunNow () {
        switch (this.jobToRun) {
            case SCHEDULED_POST_JOB: {
                this.openScheduledPostTypeModal(AutomatedJobsSchdPost.RUN_NOW_STATE);
                break;
            }
            default: this.runNow()
        }
    }

    /**
     * Update internal state tracking for scheduling
     * a new job.
     * @param {Event} evt 
     */
    handleScheduledJobUpdate (evt) {
        this.jobToSchedule = evt.detail.value;
        if (this.jobToSchedule === SCHEDULED_POST_JOB) {
            this.getExcludedTimeValues();
            this.resetJobToScheduleTime();
            this.openScheduledPostTypeModal({
                ...AutomatedJobsSchdPost.ADD_SCHD_JOBS_STATE,
                jobToScheduleTime: this.jobToScheduleTime
            });
        }
        else {
            this.timesToExclude = [];
            this.resetJobToScheduleTime();
            this.jobToScheduleTime = this.startTimes[0] && this.startTimes[0].value;
        }
    }

    /**
     * Update internal state tracking for scheduling
     * a new job at a given time.
     * @param {Event} evt 
     */
    handleScheduleJobTimeUpdate (evt) {
        this.jobToScheduleTime = evt.detail.value;
    }

    /**
     * Update internal state tracking for running
     * an on-demand job.
     * @param {Event} evt 
     */
    handleRunJobUpdate (evt) {
        this.jobToRun = evt.detail.value;
        this.jobToRun === SCHEDULED_POST_JOB && this.openScheduledPostTypeModal(AutomatedJobsSchdPost.RUN_NOW_STATE);
    }

    /**
     * Remove a scheduled job.
     */
    handleRemoveJob () {
        if (!this.jobToRemove) {
            return;
        }

        remove({
            jobId: this.jobToRemove
        }).then(() => {
            NotificationService.displayToastMessage(
                this,
                LabelService.jobRemovedSuccess,
                LabelService.commonSuccess,
                'success'
            );
        }).catch((err) => {
            console.error(err);
        }).finally(() => {
            this.handleCloseModal();
            this.refreshSchedule();
        });
    }

    /**
     * Enables edit mode for the job notification settings section.
     */
    handleEdit () {
        this.isEditable = true;
    }

    /**
     * Save changes to job notification settings.
     */
    handleSave () {
        let valid = this.template
            .querySelector('[data-id="lightningInput-keepResults"]')
            .reportValidity();

        if (valid) {

            let fields = [...this.template.querySelectorAll('[data-field]')];
            fields.forEach((field) => {
                this.accountingSettings[field.dataset.field] = CommonUtils.getFieldValue(field);
            });

            const nsSettings = this.accountingSettingsInfo.getSObject(this.accountingSettings);


            let ajrRetentionJobTime = this.template
                .querySelector('[data-id="lightningCombobox-deletionRunTime"]')
                .value;

            this.isEditable = false;

            saveSettings({
                settings: nsSettings,
                ajrRetentionJobTime: ajrRetentionJobTime
            }).then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    LabelService.notificationSettingsSuccess,
                    LabelService.commonSuccess,
                    'success'
                );
            }).catch((err) => {
                NotificationService.displayToastMessage(
                    this,
                    err.body.message,
                    LabelService.commonToastErrorTitle,
                    'error'
                );
            }).finally(() => {
                refreshApex(this.accountingSettings);
                refreshApex(this.configs);
            });
            
        }
    }

    /**
     * Discard changes to job notification settings.
     */
    handleCancel () {
        this.isEditable = false;
        let keepResultsInput = this.template
            .querySelector('[data-id="lightningInput-keepResults"]');
        let deletionRunTimeInput = this.template
            .querySelector('[data-id="lightningCombobox-deletionRunTime"]');
        let enableRecordDeletionToggleElement = this.template
            .querySelector('[data-id="lightningInput-enableRecordDeletion"]');
        let emailNotificationsToggleElement = this.template
            .querySelector('[data-id="lightningInput-emailNotifications"]');

        keepResultsInput.value = this.accountingSettings.Automated_Job_Results_Retention_Days__c;
        deletionRunTimeInput.value = this.configs.data.jobs.ajrRetentionJob.nextFire;
        enableRecordDeletionToggleElement.checked = this.accountingSettings.Enable_Retention_Period__c;
        emailNotificationsToggleElement.checked = this.accountingSettings.Disable_Email_Confirmations__c;
        setTimeout(() => {keepResultsInput.reportValidity()}, 0);
    }

    /**
     * Modal controls
     * This modal is used for deleting jobs.
     */
    handleCloseModal () {
        this.jobToRemove = null;
        this.isModalOpen = false;
    }

    handleOpenModal (evt) {
        this.jobToRemove = evt.target.dataset.sfid;
        this.isModalOpen = true;
    }

    /**
     * Lifecycle Events
     */
    connectedCallback () {
        this.refreshSchedule();
    }

    closeScheduledPostTypeModal() {
        const selectScheduledPostTypeModal = this.template.querySelector('c-modal-popup-base[data-id="selectScheduledPostTypeModal"]');
        selectScheduledPostTypeModal && selectScheduledPostTypeModal.closeModal();
    }

    openScheduledPostTypeModal(state) {
        this.scheduledPostTypeState = {...this.scheduledPostTypeState, ...state};

        const selectScheduledPostTypeModal = this.template.querySelector('c-modal-popup-base[data-id="selectScheduledPostTypeModal"]');
        selectScheduledPostTypeModal && selectScheduledPostTypeModal.openModal();
    }

    handleSchdTypeRowSelection(event) {
        this.scheduledPostTypeState.selectedSchdTypes = event.detail.selectedSchdTypes;
    }

    handleProcessJob() {
        switch (this.scheduledPostTypeState.id) {
            case AutomatedJobsSchdPost.ADD_SCHD_JOBS_STATE.id:
                this.closeScheduledPostTypeModal();
                this.addScheduledJob();
                break;
            case AutomatedJobsSchdPost.RUN_NOW_STATE.id:
                this.closeAreYouSureModal();
                this.closeScheduledPostTypeModal();
                this.runNow();
                break;
        }
    }

    openAreYouSureModal() {
        this.isHideSelectScheduledPostTypeModal = true;

        const areYouSureModal = this.template.querySelector('c-modal-popup-base[data-id="areYouSureModal"]');
        areYouSureModal && areYouSureModal.openModal();
    }

    closeAreYouSureModal() {
        this.isHideSelectScheduledPostTypeModal = false;

        const areYouSureModal = this.template.querySelector('c-modal-popup-base[data-id="areYouSureModal"]');
        areYouSureModal && areYouSureModal.closeModal();
    }

    handleShowConfirmation() {
        this.openAreYouSureModal();
    }
    prepareAccountingSettings() {
        if (this.accountingSettingsInfo && this.accountingSettingsData) {
            this.showSpinner = false;
            this.accountingSettings = this.accountingSettingsInfo.getRecord(this.accountingSettingsData);
            const packageQualifier = CommonUtils.getPackageQualifier(AccountingSettings.inventoryValuationMethod.fieldApiName)
            this.inventoryValuationMethod = this.accountingSettings[AccountingSettings.inventoryValuationMethod.fieldApiName] ||
                this.accountingSettings[AccountingSettings.inventoryValuationMethod.fieldApiName.replace(packageQualifier, '')];
        }
    }
}
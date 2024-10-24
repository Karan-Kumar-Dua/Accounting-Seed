import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CommonUtils, ErrorUtils, NotificationService, LabelService, StreamingApi } from 'c/utils';
import { 
    FinancialReporterSettings, 
    FinancialReportResult, 
    FinancialReportDefinition,
    AccountingPeriod,
    ASImmediateEvent 
} from "c/sobject";
import getSettings from '@salesforce/apex/FinancialReporterSettingsHelper.getSettingsByFinReportResult';
import getReport from '@salesforce/apex/FinancialReporterHelper.getFinancialReportResultsById';
import updateReportSubtitle from '@salesforce/apex/FinancialReporterHelper.updateReportSubtitle';
import cloneAsCustom from '@salesforce/apex/FinancialReporterHelper.cloneAsCustom';
import reRunReport from '@salesforce/apex/FinancialReporterHelper.reRunReport';
import CURRENCY from '@salesforce/i18n/currency';
import Labels from './labels';


const IMMEDIATE_CHAN = '/event/' + ASImmediateEvent.packageQualifier + 'AS_Immediate_Event__e';
const COMMIT_CHAN = '/event/' + ASImmediateEvent.packageQualifier + 'AS_Commit_Event__e';

const END_REPORT = 'FINANCIAL_REPORTER_GENERATE_END';

export default class FinReporterMainReportViewer extends NavigationMixin(LightningElement) {

    labels = {...LabelService, ...Labels};
    exportLabelWithSpecialCharacters = Labels.XCSV + '‌ ';
    @api
    reportResultId;
    objectApiName = FinancialReportResult.objectApiName;
    frResult = new FinancialReportResult();
    frs = new FinancialReporterSettings();
    frd = new FinancialReportDefinition();
    showMoreInfo = false;
    export = false;
    read = true;
    moreInfo;
    @track settingsDTO;
    reportName;
    originalSubtitle = Labels.INF_SUBTITLE_HERE;
    subtitle = Labels.INF_SUBTITLE_HERE;
    reportValues;
    error;
    cloneError;
    isError = false;
    isCustomReport = false;
    showSpinner = false;
    immediateChan = new StreamingApi();
    commitChan = new StreamingApi();
    objEvent = new ASImmediateEvent();

    receiveSettings() {
        return getSettings({finReportResultId: this.reportResultId})
            .then(result => {
                this.settingsDTO = result;
            })
            .catch(e => {
                let {isError, error} = ErrorUtils.processError(e);
                this.error = error;
                this.isError = true;
            });
    }

    receiveReport() {
        return getReport({reportId: this.reportResultId})
          .then(result => {
              this.reportName = result.reportDefinition.Name;
              if (result.reportDefinition[this.frd.subtitle]) {
                  this.subtitle = this.originalSubtitle = result.reportDefinition[this.frd.subtitle];
              }

              if (result.reportResult[this.frResult.report_type] === 'Custom Report') {
                  this.isCustomReport = true;
              }
              this.reportValues = result;
          })
          .catch(e => {
              let {isError, error} = ErrorUtils.processError(e);
              this.error = error;
              this.isError = isError;
          });
    }

    get logoUrl() {
        let url = '';
        if (this.settingsDTO && this.settingsDTO.companyLogoId) {
            url = '/sfc/servlet.shepherd/version/download/'  + this.settingsDTO.companyLogoId;
        }
        return url;
    }

    get companyName() {
        if (this.settingsDTO) {
            return CommonUtils.getDataValue(
                this.frs.company_name, this.settingsDTO.settings
            );
        }
    }

    get reportResultCurrency() {
        return this.reportValues && this.reportValues.reportResult && this.reportValues.reportResult.CurrencyIsoCode || CURRENCY;
    }

    get moreInfoIcon() {
        return this.showMoreInfo ? 'utility:down' : 'utility:right';
    }
    get exportIcon() {
        return this.export ? 'utility:up' : 'utility:down';
    }
    get showBudgetLedger() {
        return this.reportValues && this.reportValues.reportResult && this.reportValues.reportResult[this.frResult.budget_ledger];
    }
    get showGlav1() {
        return this.reportValues && this.reportValues.reportResult && this.reportValues.reportResult[this.frResult.gl_account_variable_1];
    }
    get showGlav2() {
        return this.reportValues && this.reportValues.reportResult && this.reportValues.reportResult[this.frResult.gl_account_variable_2];
    }
    get showGlav3() {
        return this.reportValues && this.reportValues.reportResult && this.reportValues.reportResult[this.frResult.gl_account_variable_3];
    }
    get showGlav4() {
        return this.reportValues && this.reportValues.reportResult && this.reportValues.reportResult[this.frResult.gl_account_variable_4];
    }
    get glav1Label() {
        return this.getFieldLabel(this.frResult.gl_account_variable_1);
    }
    get glav2Label() {
        return this.getFieldLabel(this.frResult.gl_account_variable_2);
    }
    get glav3Label() {
        return this.getFieldLabel(this.frResult.gl_account_variable_3);
    }
    get glav4Label() {
        return this.getFieldLabel(this.frResult.gl_account_variable_4);
    }

    get exportOptions() {
        return [
            {
                label: LabelService.commonExcel, 
                value: 'Excel', 
                href: `/apex/${FinancialReportResult.packageQualifier}ReportViewerPDF?Id=${this.reportResultId}&output=xls`,
                target: "_blank" 
            }, {
                label: LabelService.commonPDF,   
                value: 'PDF',   
                href: `/apex/${FinancialReportResult.packageQualifier}ReportViewerPDF?Id=${this.reportResultId}`,
                target: "_blank"
            }
        ];
    }

    get notes() {
        let notes;
        if (this.reportValues && this.reportValues.reportDefinition[this.frd.name_field] === 'Balance Sheet') {
            // if this report is a balance sheet
            const prd = Object.values(this.reportValues.reportPeriodsByOffset)
                .find(x => x[AccountingPeriod.status.fieldApiName] === 'Open');

            if (prd) {
                // if an open period exists
                notes = LabelService.reportCurrentYearEarningsNote.replace('{0}', prd[AccountingPeriod.name_field.fieldApiName] );
            }
        }
        if (this.reportValues && this.reportValues.missingOpeningBalanceData) {
            notes = LabelService.reportOpeningBalanceNote;
        }
        return notes;
    }
    
    get roundingDescription() {
        const reportRounding = this.reportValues 
            && this.reportValues.reportResult 
            && this.reportValues.reportResult[this.frResult.rounding];
        switch(reportRounding) {
            case 'Round to 1000s':
                return Labels.INF_ROUNDED_TO_1000s;
            case 'Whole Amounts':
                return Labels.INF_ROUNDED_TO_WHOLE_AMOUNTS;
            default:
                return '';
        }
    }

    get showCloneReportButton() {
        return !(this.isCustomReport || this.isCashFlowReport() || this.isTrialBalanceReport());
    }

    getFieldLabel = fieldApiName => this.moreInfo && this.moreInfo.objectInfos[this.objectApiName].fields[fieldApiName].label;

    handleMoreInfoBtn() {
        this.showMoreInfo = !this.showMoreInfo;
    }

    handleEdit() {
        this.toggleRead();
    }

    handleCancel() {
        this.subtitle = this.originalSubtitle;
        this.toggleRead();
    }

    handleSave() {
        updateReportSubtitle({reportId: this.reportResultId, subtitle: this.subtitle})
          .then(result => {
              if (result.isSuccess) {
                  this.originalSubtitle = this.subtitle;
              }
          })
          .catch(e => {
              let {isError, error} = ErrorUtils.processError(e);
              this.error = error;
              this.isError = isError;
          });
        this.toggleRead();
    }

    handleValueChange(event) {
        this.subtitle = event.detail.value;
    }

    handleExpandAll() {
        let report = this.reportViewContainer();
        if (report) {
            report.expandAll();
        }
    }

    handleCollapseAll() {
        let report = this.reportViewContainer();
        if (report) {
            report.collapseAll();
        }
    }

    handleMoreInfoLoad({detail}) {
        if (detail) {
            this.moreInfo = detail;
        }
    }

    connectedCallback() {
        this.commitChan.channelName = COMMIT_CHAN;
        this.commitChan.handleSubscribe(this.updateCallback);
    
        this.immediateChan.channelName = IMMEDIATE_CHAN;
        this.immediateChan.handleSubscribe(this.updateCallback);

        this.loadRecords();
    }

    disconnectedCallback() {
        this.commitChan.handleUnsubscribe();
        this.immediateChan.handleUnsubscribe();
    }

    updateCallback = response => {
        if (response) {
          this.commitChan.responseError = null;
          this.immediateChan.responseError = null;
          if (response.data.payload[this.objEvent.type] === END_REPORT) {
            this[NavigationMixin.GenerateUrl]({
                type: "standard__component",
                attributes: {
                    componentName: "AcctSeed__FinancialReportViewerProxy"
                },
                state: {
                    AcctSeed__recordId: response.data.payload[this.objEvent.record_id]
                }
            }).then((url) => {
                const event = new ShowToastEvent({
                    title: LabelService.commonFinancialReports,
                    message: LabelService.reportGenerationCompleteWithLink,
                    messageData: [
                        {
                            url,
                            label: 'here',
                        },
                    ],
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(event);
            });

           
        
          }
        }
        else {
          if (this.commitChan.responseError) {
            this.error = this.commitChan.responseError;
          }
          else if (this.immediateChan.responseError) {
            this.error = this.immediateChan.responseError;
          }
        }
    
    }

    renderedCallback() {
        if (this.settingsDTO && !this.isCustomReport && this.isFirstRun) {
            CommonUtils.getDataValue(this.frs.expand_report_rows, this.settingsDTO.settings) && this.handleExpandAll();
            this.isFirstRun = false;
        }
    }

    async loadRecords() {
        await this.receiveSettings();
        this.receiveReport();
        this.isFirstRun = true;
    }

    cloneReport() {
        this.cloneError = null;
        const nameInput = this.getCloneReportNameInput();
        nameInput && nameInput.value && (nameInput.value = nameInput.value.trim());
        if (nameInput && nameInput.reportValidity()) {
            const descriptionInput = this.template.querySelector('lightning-textarea[data-id="cloneReportDescriptionInput"]');
            this.showSpinner = true;
            cloneAsCustom({params: {
                    name: nameInput.value,
                    description: descriptionInput && descriptionInput.value,
                    reportId: this.reportResultId
                }})
                .then(result => {
                    if (result.definitionId) {
                        NotificationService.displayToastMessage(this, LabelService.reportClonedSuccessfully, LabelService.commonFinancialReports, 'success');
                        this.closeCloneReport();
                        this.navigateToDefenitionPage(result.definitionId);
                    }
                })
                .catch(e => {
                    let {error} = ErrorUtils.processError(e);
                    this.cloneError = error;
                })
                .finally(() => {this.showSpinner = false});
        }
    }

    reRunFinancialReport(){
        reRunReport({reportId: this.reportResultId})
        .then(result => {
          if (result.isSuccess) {
            NotificationService.displayToastMessage(this, LabelService.reportGenerationInProgress, LabelService.commonFinancialReports, 'success');
          } else {
            NotificationService.displayToastMessage(this, result.errors[0].detail, LabelService.commonFinancialReports, 'error');
          }
        }).catch(e => this.processError(e));

    }

    navigateToDefenitionPage(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: FinancialReportDefinition.objectApiName,
                actionName: 'view'
            }
        });

    }

    closeCloneReport() {
        this.cloneError = null;
        const previewCloneReport = this.getCloneReportModal();
        previewCloneReport && previewCloneReport.closeModal();
    }

    openCloneReport() {
        const previewCloneReport = this.getCloneReportModal();
        previewCloneReport && previewCloneReport.openModal();
    }

    isCashFlowReport = () => this.reportValues && this.reportValues.reportDefinition[this.frd.name_field] === 'Cash Flow Statement';
    isTrialBalanceReport = () => this.reportValues && this.reportValues.reportDefinition[this.frd.name_field] === 'Trial Balance';
    getCloneReportModal = () => this.template.querySelector('c-modal-popup-base[data-id="previewCloneReport"]');
    getCloneReportNameInput = () => this.template.querySelector('lightning-input[data-id="cloneReportNameInput"]');
    reportViewContainer = () => this.template.querySelector('c-fin-reporter-view-container');
    toggleRead = () => this.read = !this.read;

}
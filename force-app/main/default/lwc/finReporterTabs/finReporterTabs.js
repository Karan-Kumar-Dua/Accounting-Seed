import { api, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAccountingDashboard from '@salesforce/apex/FinancialReporterHelper.getAccountingDashboard';
import { KnowledgeBase, LabelService } from 'c/utils';
import Labels from "./labels";

export default class FinReporterTabs extends NavigationMixin(LightningElement) {

  labels = {...Labels, ...LabelService};

  @api activeTab;
  @api activeReportValue;
  @api ledgerId;
  @api glAccountId;
  @api defaultAcctPeriod;
  @api defaultglav1;
  @api defaultglav2;
  @api defaultglav3;
  @api defaultglav4;

  headerValue = Labels.INF_STANDARD_REPORTS;
  headerIcon = 'standard:account';
  headerTitle = LabelService.commonFinancialReports;
  
  tabValues = {
    standardReports: 'standardReports',
    customReports: 'customReports',
    reportSettings: 'reportSettings',
    runConsolidations: 'runConsolidations',
    setupConsolidations: 'setupConsolidations'
  };

  get activeTabValue() {
    return this.tabValues[this.activeTab];
  }

  activeStandardReportsTab() {
    this.headerValue = Labels.INF_STANDARD_REPORTS;
    this.headerIcon = 'standard:account';
    this.headerTitle = LabelService.commonFinancialReports;
  }

  activeCustomReportsTab() {
    this.headerValue = LabelService.commonCustomReports;
    this.headerIcon = 'standard:account';
    this.headerTitle = LabelService.commonFinancialReports;
  }

  activeSettingsTab() {
    this.headerValue = LabelService.commonSettings;
    this.headerIcon = 'standard:account';
    this.headerTitle = LabelService.commonFinancialReports;
  }

  activeRunConsolidationsTab() {
    this.headerValue = Labels.accountingHomeRunConsolidations;
    this.headerIcon = 'standard:flow';
    this.headerTitle = 'Consolidations';
  }

  activeSetupConsolidationsTab() {
    this.headerValue = Labels.INF_LEDGER_HIERARCHY;
    this.headerIcon = 'standard:account';
    this.headerTitle = 'Consolidations';
  }

  openKB() {
    let url;
    switch(this.headerValue) {
      case 'Standard Reports':
        url = KnowledgeBase.standardReports;
        break;
      case 'Custom Reports':
        url = KnowledgeBase.customReports;
        break;
      case 'Settings':
        url = KnowledgeBase.reportSettings;
        break;
      case 'Run Consolidations':
        url = KnowledgeBase.runConsolidations;
        break;
      case 'Ledger Hierarchy':
        url = KnowledgeBase.setupConsolidations;
        break;
      default:
        url = KnowledgeBase.home;
    }

    this[NavigationMixin.Navigate]({
      "type": "standard__webPage",
      "attributes": {
        "url": url
      }
    });
  }

  openMR() {
    this[NavigationMixin.GenerateUrl]({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: 'Report',
        actionName: 'home',
      },
    }).then(url => {
      window.open(url, "_blank");
    })};

  openDB() {
    getAccountingDashboard()
        .then(result => {
              if (result) {
                this[NavigationMixin.GenerateUrl]({
                  type: 'standard__recordPage',
                  attributes: {
                    recordId: result.Id,
                    actionName: 'view',
                  },
                }).then(url => {
                  window.open(url, "_blank");
                })
              }
            }
        )
  }

  renderedCallback() {
    const style = document.createElement('style');
    style.innerText = `.slds-tabs_default__link[tabindex="0"]:focus {text-decoration: none;}`;
    this.template.querySelector('lightning-tabset').appendChild(style);
  }
}
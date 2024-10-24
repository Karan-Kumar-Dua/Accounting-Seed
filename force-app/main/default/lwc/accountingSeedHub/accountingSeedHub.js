import { LightningElement, track, wire } from 'lwc';
import { LabelService, RecordProxy, CommonUtils, ErrorUtils, NotificationService } from 'c/utils';
import { labels } from './labels';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import { CurrentPageReference } from 'lightning/navigation';
import authorizeAccountingHub from '@salesforce/apex/AccountingSeedHubHelper.authorizeAccountingHub';
import authenticateAccountingHub from '@salesforce/apex/AccountingSeedHubHelper.authenticateAccountingHub';
import DeleteAccountingSeedHubUsername from '@salesforce/apex/AccountingSeedHubHelper.DeleteAccountingSeedHubUsername';

export default class AccountingSeedHub extends LightningElement { 

    @track labels = {...LabelService, ...labels()};
    //variable used to store the data of Accounting_Settings__c record
    @track accountingSettings;
    // variable used to store the Accounting_Settings__c Object level properties like fields and its details also like helptext etc..
    @track accountingSettingsInfo;
    @track isShowSpinner = true;
    //variable used to store the authCode that comes from authorization
    @track authCode;
    @track knowledgeBase = [
        {
            url: 'https://support.accountingseed.com/hc/en-us/articles/24720267689235',
            iconName: 'standard:question_feed',
            iconAltText: 'Knowledge Base'
        }
    ]

    // wire used for getting current page details like URL,attributes and state append with URL
    @wire(CurrentPageReference)
    pageRef;

    get isLoaded() {
        return this.accountingSettings && this.accountingSettingsInfo;
    }

    //getter used to dynamically show the Authorize button label based on Hub_userName__c field value of Accounting_settings__c record
    get authorizeLabel() {
        return this.accountingSettings && this.accountingSettings.Hub_Username__c === undefined 
               ? this.labels.authorizeHubButton : this.labels.reauthorizeHubButton;
    }

    /**
     * Page header navigation
     */
    get breadcrumbs() {
        return [
            {
                title: 'Accounting Home',
                tab: `${this.accountingSettingsInfo?.namespace || CommonUtils.getPackageQualifier(ACCOUNTING_SETTINGS_OBJECT.objectApiName)}Accounting_Home2`
            },
            { title: LabelService.accountingSetup }
        ];
    }

    connectedCallback() {
        // store the auth code if present in URL from state parameter along with its namespace
        this.authCode = decodeURIComponent(this.pageRef.state[CommonUtils.getPackageQualifier(ACCOUNTING_SETTINGS_OBJECT.objectApiName)+'code']);
    }

    /**
     * Quick access to field labels instead of storing
     * these as custom labels.
     */
    @wire(getObjectInfo, { objectApiName: ACCOUNTING_SETTINGS_OBJECT })
    getAccountingSettingsInfo({ err, data }) {
        if (err) {
            NotificationService.displayToastMessage(this, ErrorUtils.processError(err).error, + this.labels.errorLabel + ':', 'error');
        }
        if (data) {
            this.accountingSettingsInfo = new RecordProxy(data);
            this.fetchAccountingSettings();
        }
    }

    /**
     * Method used to store the record value of Accoutning_settngs__c object 
     */
    fetchAccountingSettings() {
        // retrieve settings record once we can proxy it
        getSettings()
            .then((res) => {
                this.accountingSettings = this.accountingSettingsInfo.getRecord(res);
                /* if condition to make sure that if there is no value in hubusername field of accounting_Setting
                   and authCode is also not undefined which we get from URL in state Parameter then only perfrom the
                   authentication.
                */
                if (this.accountingSettings.Hub_Username__c === undefined && this.authCode !== 'undefined') {
                    this.authenticateAccountingSeedHub();
                }
                else{
                    this.isShowSpinner = false;
                }
            })
            .catch((err) => {
                NotificationService.displayToastMessage(this, ErrorUtils.processError(err).error, this.labels.errorLabel, 'error');
                this.isShowSpinner = false;
            });
    }

    /**
     * Method used to perfrom the authentication to get access token and using that token get the current authenticate
     * user name and save it in Hub_User_Name__c field 
     */
    authenticateAccountingSeedHub() {
        authenticateAccountingHub({ authCode: this.authCode })
            .then((res) => {
                this.accountingSettings = this.accountingSettingsInfo.getRecord(res);
                // to remove "AcctSeed__code" queryparams from URL after completion of authentication
                window.history.pushState({}, document.title, window.location.pathname);
            })
            .catch((err) => {
                NotificationService.displayToastMessage(this, ErrorUtils.processError(err).error, this.labels.accountingSeedHubAuthorizationError, 'error');
            })
            .finally(() => {
                this.isShowSpinner = false;
            });
    }

    /**
     * 
     * method used to perfrom first step on click of Athirize button to perfrom Authorization which will give
     * auth code to perfrom further authentication.
     */
    async authorizeHub(event) {
        try {
            this.isShowSpinner = true;
            let result;
            let promiseRes;
            if(event.target.label === this.labels.reauthorizeHubButton) {
                /*need promise.allSettled to reduce server time and waiting time on front end side to better look and feel.
                  and also if btton label is re-Authorize then delete the exisiting user name saved in Hub_UserName__c field
                  of Accounting_settings__c and re-initiate the auth flow and promise.allSettled takes care of both apex calls
                  simultaneously in which first is deletion of user name from hub_UserName__c field and second is getting the auth code again
                  to perfrom authentication and then get new user name.
                */
                promiseRes = await Promise.allSettled([DeleteAccountingSeedHubUsername(), authorizeAccountingHub()]);
            }
            else {
                // if button label is Authorize means no user name present.
                result = await authorizeAccountingHub();
            }
            
            if(promiseRes && promiseRes[0].status === 'fulfilled' && promiseRes[1].status === 'fulfilled') {
               result = promiseRes[1].value ;
            }
            /* prepare SF oAuth URl along with current Authorize AccountingSeedHub tab Name and passed it in state
               parameter of auth URL and hit it in browser using window methods that will give us the auth code in URL 
               itself on load of page.
            */
            let fullUrl =  result + '&state='+window.location.origin + '/lightning/n/' + this.pageRef.attributes.apiName;
            window.open(fullUrl, "_self");
        }
        catch (err) {
            NotificationService.displayToastMessage(this, ErrorUtils.processError(err).error, this.labels.accountingSeedHubAuthorizationError, 'error');
            this.isShowSpinner = false;
        }
    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        if (isError) {
            this.error = error;
            this.isError = isError;        
        } else {
            this.error = error.toString();
            this.isError = true;
        }
    }
}
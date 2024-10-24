import { LightningElement, track, wire, api } from 'lwc';
import { NotificationService, StreamingApi, LabelService } from "c/utils";
import { ppLables } from './publishPaymentProposalLabels';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from "lightning/uiRecordApi";
import { ASImmediateEvent } from "c/sobject";
import publishSinglePaymentProposal from "@salesforce/apex/PaymentProposal.publishSinglePaymentProposal";
import PP_NAME_FIELD from "@salesforce/schema/Payment_Proposal__c.Name";
import PP_STATUS_FIELD from "@salesforce/schema/Payment_Proposal__c.Status__c";
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';

const CHANNEL_NAME = '/event/' + ASImmediateEvent.packageQualifier + 'AS_Immediate_Event__e';

export default class PublishPaymentProposal extends LightningElement {
    @api recordId;

    @track labelFactory = { ...LabelService, ...ppLables() };
    @track fields = [PP_NAME_FIELD, PP_STATUS_FIELD];
    @track ppObject;
    @track paymentProposalLineRecs=[];
    @track isShowSpinner = true;

    objEvent = new ASImmediateEvent();
    sa = new StreamingApi();

    get ppStatusMessage() { 
        if((this.ppObject && this.ppObject[this.fields[1].fieldApiName] !== 'Approved')){
            return this.labelFactory.PP_APPROVE_TO_PAY;
        }else if(this.paymentProposalLineRecs.length === 0){
            return this.labelFactory.ERR_PP_NO_PAYMENT_PROPOSAL_LINES_TO_PAY;
        }else{
            return this.labelFactory.TO_PUBLISH_PAYMENT_PROPOSAL;
        }
    }

    get yesDisabled() {
        return ((this.ppObject && this.ppObject[this.fields[1].fieldApiName] !== 'Approved') || (this.paymentProposalLineRecs.length === 0));
    }

    connectedCallback() {
        this.sa.channelName = CHANNEL_NAME;
        this.sa.customErrorCallback = this.errorCallback;
        this.sa.handleSubscribe(this.updateCallback);
    }

    renderedCallback() {
        let messageElment = this.refs.ppMsg;
        messageElment.className = this.yesDisabled ? 'slds-text-align_center slds-text-color_error' : 'slds-text-align_center';
    }

    updateCallback = response => {
        try {
            if (response) {
                if (response.data.payload[this.objEvent.type] === 'PAYMENT_PROPOSAL_PUBLISH_START') {
                    NotificationService.displayToastMessage(
                        this,
                        this.labelFactory.PP_PUBLISH_JOB_START = this.labelFactory.PP_PUBLISH_JOB_START.replace("{0}", this.ppObject[this.fields[0].fieldApiName]),
                        this.labelFactory.commonSuccess,
                        this.labelFactory.commonSuccess
                    );
                    this.sa.handleUnsubscribe();
                }
            }
            this.closeAction();
            this.isShowSpinner = false;

        } catch (err) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(err),
                this.labelFactory.commonErrorText,
                this.labelFactory.commonErrorText
            );
        }
    };

    @wire(getRecord, {
        recordId: "$recordId",
        fields: "$fields",
    })
    fetchCommonRecord({ data, error }) {
        if (data) {
            let paymentProposalObject = {};
            paymentProposalObject['Id'] = this.recordId;
            paymentProposalObject[this.fields[0].fieldApiName] = data.fields[this.fields[0].fieldApiName].value;
            paymentProposalObject[this.fields[1].fieldApiName] = data.fields[this.fields[1].fieldApiName].value;
            this.ppObject = paymentProposalObject;
            let payPP = this.labelFactory.PUBLISH_PAYMENT_PROPOSAL_MSG;
            this.labelFactory.PUBLISH_PAYMENT_PROPOSAL_MSG = payPP.replace("{0}", this.ppObject[this.fields[0].fieldApiName]);
            this.isShowSpinner = false;
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(error),
                this.labelFactory.commonErrorText,
                this.labelFactory.commonErrorText
            );
            this.isShowSpinner = false;
        }
    }

    @wire(getRelatedListRecords, {
        parentRecordId: "$recordId",
        relatedListId: 'AcctSeed__Payment_Proposal_Lines__r',
      })
      getPplRecordsList({ error, data }) {
        if (data) {
          this.paymentProposalLineRecs = data.records;
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(error),
                this.labelFactory.commonErrorText,
                this.labelFactory.commonErrorText
            );
        }
      }

    async processJobs() {
        try {
            this.isShowSpinner = true;
            let result = await publishSinglePaymentProposal({ ppJSON: JSON.stringify(this.ppObject) });
        }
        catch (err) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(err),
                this.labelFactory.commonErrorText,
                this.labelFactory.commonErrorText
            );
            this.isShowSpinner = false;
        }
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
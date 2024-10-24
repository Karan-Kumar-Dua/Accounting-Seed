import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getNext from '@salesforce/apex/TimeCardHelper.getNext';

export default class TimeCardNew extends NavigationMixin(LightningElement) {

    @wire(CurrentPageReference)
    wirePageRef(data) {
        try {
            this.getNextTimeCard(data);
        } catch(err) {
            this.navigateToForm();
        }
    }

    async getNextTimeCard(pageRef) {
        try {
            const url = await this.getCtxUrl(pageRef);
            const timecard = await getNext();
            const defaults = encodeDefaultFieldValues(timecard);
            this.navigateToForm(defaults, url);
        } catch(err) {
            this.navigateToForm();
        }
    }

    getCtxUrl(pageRef) {
        if (!pageRef || !pageRef.state || !pageRef.state.inContextOfRef) {
            return;
        }
        let ctxB64 = pageRef.state.inContextOfRef;
        if (ctxB64.startsWith("1\.")) {
            ctxB64 = ctxB64.substring(2);
        }
        const ctx = JSON.parse(window.atob(ctxB64));
        return this[NavigationMixin.GenerateUrl](ctx);
    }

    navigateToForm(formDefaults, backgroundCtx) {
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "AcctSeed__Time_Card__c",
                actionName: "new"
            },
            state: {
                nooverride: 1,
                defaultFieldValues: formDefaults,
                backgroundContext: backgroundCtx
            }
        });
    }

}
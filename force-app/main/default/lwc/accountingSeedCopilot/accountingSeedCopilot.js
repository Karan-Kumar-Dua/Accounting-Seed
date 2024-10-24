import Id from "@salesforce/user/Id";
import commandBarBundle from "@salesforce/resourceUrl/commandbar";
import { LightningElement } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import getContext from '@salesforce/apex/AccountingSeedCopilot.getContext';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Labels from './labels';

export default class AccountingSeedCopilot extends LightningElement {

    labels = {...Labels};
    userId = Id;
    orgId = "30960340";
    organizationId;
    async connectedCallback() {
        try {
            await loadScript(this, commandBarBundle + "/index.js");
            getContext()
                .then( async(ctx) => {
                    const organizationId = ctx.OrganizationId;
                    const userIdentifier = organizationId + '-' + this.userId + '-' + ctx.UserEmail;
                    window.CommandBarModule.init(this.orgId, {environment: ctx.Environment});
                    for(const key of Object.keys(ctx)){
                        window.CommandBar.addMetadata(key, ctx[key]);
                    }
                    if(ctx.UserType === 'Standard'){
                        await window.CommandBar.boot(userIdentifier, {
                            organizationId: organizationId
                        });
                    }
                }, err => {
                    const event = new ShowToastEvent({
                        variant: "warning",
                        title: this.labels.ACCOUNTING_SEED_COPILOT,
                        message:
                            this.labels.ERR_ACCOUNTING_SEED_COPILOT_LOAD + ': ' + err,
                    });
                    this.dispatchEvent(event);

                })

        } catch (error) {
            const event = new ShowToastEvent({
                variant: "warning",
                title: this.labels.ACCOUNTING_SEED_COPILOT,
                message:
                this.labels.ERR_ACCOUNTING_SEED_COPILOT_LOAD,
            });
            this.dispatchEvent(event);
        }
    }
}
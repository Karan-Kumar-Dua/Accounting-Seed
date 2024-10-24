import {LightningElement, api} from 'lwc';
import pingAvaTax from '@salesforce/apex/AccountingSettingsHelper.pingAvaTax';
import {NotificationService, ErrorUtils} from 'c/utils';
import Labels from './labels';
import { LabelService } from "c/utils";

export default class TestTaxConnection extends LightningElement {
    @api
    recordId;

    @api
    invoke() {
        this.testConnections();
    }

    testConnections () {
        pingAvaTax({licenseId: this.recordId}).then((res) => {
            if (res.authenticated) {
                NotificationService.displayToastMessage(
                    this,
                    `${Labels.INF_CREDENTIAL_SUCCESSFULLY_AUTHENTICATED}
                    ${Labels.INF_AUTHENTICATION_TYPE} ${res.authenticationType}
                    ${Labels.INF_AVALARA_ACCOUNT_ID} ${res.authenticatedAccountId}`,
                    LabelService.commonSuccess,
                    'success'
                )
            }
            else {
                NotificationService.displayToastMessage(
                    this,
                    Labels.ERR_NOT_AUTHENTICATE_ACCOUNT_AVALARA_SERVICE,
                    LabelService.commonToastErrorTitle,
                    'error'
                )
            };
        }).catch((err) => {
            const {error} = ErrorUtils.processError(err);
            NotificationService.displayToastMessage(
                this,
                error,
                LabelService.commonToastErrorTitle,
                'error'
            );
        });
    }
}
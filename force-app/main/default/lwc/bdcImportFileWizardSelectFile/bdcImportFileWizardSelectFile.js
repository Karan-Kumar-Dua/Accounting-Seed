import {api, LightningElement, track} from 'lwc';
import parseFile from '@salesforce/apex/ImportFileWizardHelper.parseFile';
import { ErrorUtils, LabelService } from "c/utils";
import Labels from './labels';

export default class BdcImportFileWizardSelectFile extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api resolveNextStep() {
        if (this.importFileDto.isValid) {
            this.fireNextStepSuccessEvent();
        }
        else {
            this.error.msg = this.importFileDto.message;
        }
    }

    @track error = { title: LabelService.commonToastErrorTitle };
    importFileDto = {
        isValid: false,
        message: Labels.ERR_UPLOAD_VALID_OFX_FILE
    };
    isSpinner = false;
    contentDocumentId;

    get acceptedFormats() {
        return ['.ofx', '.qfx'];
    }

    fireNextStepSuccessEvent() {
        this.dispatchEvent(new CustomEvent('nextstepsuccess', {detail: this.importFileDto}));
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.contentDocumentId = uploadedFiles[0].documentId;
        this.processUploadedFile();
    }

    processUploadedFile() {
        this.isSpinner = true;
        this.error.msg = null;
        parseFile({ contentDocumentId: this.contentDocumentId })
            .then(result => {
                this.importFileDto = result;
                if (result.isValid) {
                    this.isSpinner = false;
                    this.focusOnNextStepBtn();
                }
                else {
                    this.error.msg = result.message;
                    this.isSpinner = false;
                    this.focusOnCrossIcon();
                }
            })
            .catch(error => {
                const parsedError = ErrorUtils.processError(error);
                this.error.msg = parsedError.error;
                this.importFileDto = {
                    isValid: false,
                    message: parsedError.error
                };
                this.isSpinner = false;

                this.focusOnCrossIcon();
            });
    }

    focusOnNextStepBtn() {
        this.dispatchEvent(new CustomEvent('focusnextbtn'));
    }

    focusOnCrossIcon() {
        this.dispatchEvent(new CustomEvent('focusoncrossicon', { bubbles: true }));
    }
}
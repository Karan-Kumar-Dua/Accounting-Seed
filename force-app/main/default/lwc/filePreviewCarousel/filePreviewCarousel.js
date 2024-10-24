import {LightningElement, api, wire, track} from 'lwc';
import {LabelService} from "c/utils";
import getRelatedFilesByRecordId from '@salesforce/apex/FilePreviewCarouselController.getRelatedFilesByRecordId';
import setDefaultFileId from '@salesforce/apex/FilePreviewCarouselController.setDefaultFileId';
import getPreviewAvailability from '@salesforce/apex/FilePreviewCarouselController.checkPreviewAvailability';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import Labels from './labels';

export default class FilePreviewCarousel extends LightningElement {

    labels = {...Labels, ...LabelService};
    @api fileId;
    @api recordId;
    @api showHeader;
    @api headerText;
    @api displayFileName;
    @api fieldNameForFileID;
    @api hideHeaderSection = false;
    @track relatedFiles = {};
    @track hasRelatedFiles = false;
    @track isLoading = false;
    @track isLoadingImage = false;
    @track fileMap = new Map();
    @track fileNumberings = [];
    @track currentFile;
    @track totalCount;
    showDefaultButton = false;
    currentIndex = 0;
    previewAvailableContentDocumentIds = new Set();
    previewNotAvailableContentDocumentIds = new Set();
    dataToRefresh = [];
    setDefaultDot = true;
    zoom = 1;
    params = '';

    connectedCallback() {
        if (this.fieldNameForFileID) {
            this.showDefaultButton = true;
        }

        let localParams = {
            'recordId': this.recordId,
            'fileId': this.fileId,
            'fieldNameForFileID': this.fieldNameForFileID
        };

        this.params = JSON.stringify(localParams);
    }

    renderedCallback() {
        if (this.setDefaultDot && (this.hideHeaderSection === false)) {
            this.makeNumberDotActiveForCurrentFile();
        }
    }

    @wire(getRelatedFilesByRecordId, {params: '$params'})
    wiredRelatedFiles(result) {
        if (result.data) {
            this.relatedFiles = result.data;
            this.dataToRefresh = result;
            document.documentElement.style.setProperty('--totalFiles', result.data.length?.toString());
            this.fileMap = new Map();
            this.fileNumberings = [];
            this.totalCount = result.data.length;
            if (this.totalCount > 0) {
                this.disableArrow(this.totalCount);
                this.hasRelatedFiles = true;
                for (let i = 0; i < result.data.length; i++) {
                    this.fileMap.set(i, result.data[i]);
                    let defaultFileStyle = '';

                    //Show default file on component load.
                    if (result.data[i].isDefaultFile) {
                        this.currentIndex = i;
                        defaultFileStyle = 'Background-color: mediumseagreen; color: white;'    //Always highlight the default file number dot
                    }

                    this.fileNumberings.push({
                        number: i + 1,
                        title: result.data[i].fileTitle,
                        defaultFileStyle: defaultFileStyle
                    });
                }

                let currentFile = JSON.parse(JSON.stringify(this.fileMap.get(this.currentIndex)));
                if (!this.previewAvailableContentDocumentIds.has(currentFile.contentDocumentId) && !this.previewNotAvailableContentDocumentIds.has(currentFile.contentDocumentId)) {
                    currentFile['isPreviewAvailable'] = this.checkPreviewAvailability(currentFile);
                } else if (this.previewAvailableContentDocumentIds.has(currentFile.contentDocumentId)) {
                    currentFile['isPreviewAvailable'] = true;
                } else if (this.previewNotAvailableContentDocumentIds.has(currentFile.contentDocumentId)) {
                    currentFile['isPreviewAvailable'] = false;
                }
                this.currentFile = currentFile;
                this.fileMap.set(this.currentIndex, currentFile);
            }
        } else if (result.error) {
            console.log(result.error);
            this.error = result.error;
        }
    }

    handleZoom() {
        this.zoom += 0.1;
        this.template.querySelector('.ImageContainer').style.transform = `scale(${this.zoom})`;
    }

    handleZoomOut() {
        this.zoom -= 0.1;
        this.template.querySelector('.ImageContainer').style.transform = `scale(${this.zoom})`;
    }

    handleZoomInit() {
        this.zoom = 1;
        let imgContainer = this.template.querySelector('.ImageContainer');
        if (imgContainer) {
            imgContainer.style.transform = `scale(${this.zoom})`;
        }
    }

    handleClick(event) {
        this.isLoading = true;
        setDefaultFileId({
            recordId: this.recordId,
            fieldName: this.fieldNameForFileID,
            extId: event.currentTarget.dataset.extId
        })
            .then(() => {
                refreshApex(this.dataToRefresh);
                this.isLoading = false;
                this.showToast('Success!', 'File set as default', 'success');

            })
            .catch((error) => {
                this.message = 'Error received: code' + error.errorCode + ', ' + 'message ' + error.body.message;
                this.isLoading = false;
            });
    }

    handleNumberClick(event) {
        let index = Number(event.target.dataset.index);
        if (this.currentIndex !== index) {
            this.currentIndex = index;
            this.makeNumberDotActiveForCurrentFile();
        }
    }

    handleShowNextOrPrevious(event) {
        this.isLoading = true;
        let num = Number(event.target.dataset.number);
        this.currentIndex += num;
        if (this.currentIndex >= this.relatedFiles.length) {
            this.currentIndex = 0;
        } else if (this.currentIndex < 0) {
            this.currentIndex = this.relatedFiles.length - 1;
        }

        this.makeNumberDotActiveForCurrentFile();
    }

    async checkPreviewAvailability(currentFile) {

        let isPreviewAvailable = this.previewAvailableContentDocumentIds.has(currentFile.contentDocumentId) ? true : (this.previewNotAvailableContentDocumentIds.has(currentFile.contentDocumentId) ? false : true);

        if (currentFile && !currentFile.isPdf && (!this.previewAvailableContentDocumentIds.has(currentFile.contentDocumentId) && !this.previewNotAvailableContentDocumentIds.has(currentFile.contentDocumentId))) {
            await getPreviewAvailability({ contentDocumentId: currentFile.contentDocumentId }).then((result) => {
                if (result) {
                    this.previewAvailableContentDocumentIds.add(currentFile.contentDocumentId);
                } else {
                    this.previewNotAvailableContentDocumentIds.add(currentFile.contentDocumentId);
                }
                isPreviewAvailable = result;
            })
        }
        return isPreviewAvailable;
    }

    async makeNumberDotActiveForCurrentFile() {
        let currentFile = this.fileMap.get(this.currentIndex);
        if (currentFile) {
            currentFile = JSON.parse(JSON.stringify(currentFile));
            currentFile['isPreviewAvailable'] = await this.checkPreviewAvailability(currentFile);
            this.currentFile = currentFile;
            this.isLoading = false;
            this.fileMap.set(this.currentIndex, currentFile);
        }

        if (this.currentFile && !this.currentFile.renderAsPdf && this.currentFile.isPreviewAvailable) {
            this.isLoadingImage = true;
            this.handleZoomInit();
        }
        let activeDotElements = this.template.querySelectorAll(".activeDot");
        let dotElements = this.template.querySelectorAll(".dot");
        if (activeDotElements && activeDotElements[0]) {
            activeDotElements[0].classList.remove('activeDot');
        }
        if (dotElements && dotElements[this.currentIndex]) {
            dotElements[this.currentIndex].classList.add('activeDot');
            this.setDefaultDot = false;
        }

        if (this.currentFile && !this.currentFile.renderAsPdf) {
            const imageContainer = this.template.querySelectorAll(".ImageContainer");
            if (imageContainer[0]) {
                imageContainer[0].removeChild(imageContainer[0].firstElementChild);
                const imageNode = document.createElement("img");
                imageNode.src = this.currentFile.previewUrl;
                imageNode.key = this.currentIndex;
                imageContainer[0].appendChild(imageNode);
            }
        }
    }

    onImageLoad() {
        this.isLoadingImage = false;
    }

    showToast(title, msg, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    disableArrow(totalCount) {
        if (totalCount === 1) {
            let css = document.documentElement.style;
            css.setProperty('--arrow-color', 'grey');
            css.setProperty('--arrow-pointer-events', 'none');
            css.setProperty('--arrow-container-hover', 'transparent');
        }
    }

}
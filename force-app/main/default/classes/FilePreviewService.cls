public with sharing class FilePreviewService{
    public static Boolean checkPreviewAvailability(String contentDocumentId){
        Boolean previewAvailable = false;
        try{
            HttpRequest request = new HttpRequest();
            if(!Test.isRunningTest()){
                request.setHeader('Authorization', 'Bearer ' + Page.AcctSeed__xUserSessionId.getContent().toString().trim());
            }
            request.setHeader('Content-Type', 'application/json');
            request.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v60.0/connect/files/' + contentDocumentId + '/previews');
            request.setMethod('GET');
            
            Http h = new Http();
            HttpResponse response = h.send(request);
            
            FilePreviewResponse filePreview = (FilePreviewResponse)JSON.deserialize(response.getBody(), FilePreviewResponse.class);
            
            for (FilePreviewWrapper preview : filePreview.previews){
                if (preview.status == 'Available'){
                    previewAvailable = true;
                    break;
                }
            }
        } catch (Exception e){
            System.debug(e.getMessage() + ' ' + e.getLineNumber());
        }
        return previewAvailable;
    }

    @TestVisible
    private class FilePreviewWrapper{
        @TestVisible
        private String format;
        @TestVisible
        private String status;
    }

    @TestVisible
    private class FilePreviewResponse{
        @TestVisible
        private FilePreviewWrapper[] previews;
        
    }
    
}
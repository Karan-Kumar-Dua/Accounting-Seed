public with sharing class FAnalyticsTemplateHandler extends WaveTemplate.WaveTemplateConfigurationModifier {

    public override void onConfigurationRetrieval(WaveTemplate.WaveTemplateInfo template) {
        if (!FeatureManagementHandler.isFAnalyticsEnabled()) {
            throw new WaveTemplate.TemplateInterruptException(Label.ERR_FANALYTICS_NOT_ENABLED);
        }
    }

}
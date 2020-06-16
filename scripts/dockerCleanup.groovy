import org.sonatype.nexus.repository.storage.Asset;
import org.sonatype.nexus.repository.storage.Query;
import org.sonatype.nexus.repository.storage.StorageFacet;
import groovy.json.JsonOutput;
import groovy.json.JsonSlurper;

def request = new JsonSlurper().parseText(args);
println(request);


assert request.repoName: 'repoName parameter is required';
assert request.startDate: 'startDate parameter is required, format: yyyy-mm-dd';
assert request.url: 'Assest url is required, format: %/cache/%';
assert request.timeFilter instanceof String;
assert request.notDownloaded instanceof String;

def tq = request.timeFilter.toString() + ' < ';
def repo = repository.repositoryManager.get(request.repoName);
StorageFacet storageFacet = repo.facet(StorageFacet);
def tx = storageFacet.txSupplier().get();
def urls = [];

try {
    tx.begin();
    Query query = new Query(String where, String suffix, Map parameters);
    if (request.notDownloaded == 'true' && request.timeFilter == 'last_downloaded') {
        println('notDownloaded condition is running');
        tq = 'blob_updated < ';
        query = Query.builder().where(tq.toString()).param(request.startDate).and('name MATCHES').param(request.url).and('last_downloaded').isNull().suffix('limit 200').build();
    } else {
        println('Normal condition is running');
        query = Query.builder().where(tq.toString()).param(request.startDate).and('name MATCHES').param(request.url).suffix('limit 200').build();
    };
    Iterable<Asset> assets = tx.findAssets(query, [repo]);
    while(!assets.isEmpty()) {
        urls << assets.collect {'/repository/'+ repo.name + '/' + it.name()};
        assets.each { asset ->
            log.info('Deleting asset ' + asset.name());
            tx.deleteAsset(asset);
            if (asset.componentId() != null) {
                log.info('Deleting component for asset ' + asset.name());
                def component = tx.findComponent(asset.componentId());
                tx.deleteComponent(component);
            };
        };
        assets = tx.findAssets(query, [repo]);
    };
    tx.commit();
    def result = JsonOutput.toJson([
        assets  : urls,
        query   : tq.toString(),
        query_term : request.url,
        before  : request.startDate,
        notDownloaded: request.notDownloaded,
        repoName: request.repoName
    ]);
    log.info(JsonOutput.prettyPrint(result));
    return result;
} catch (Exception e) {
    log.warn('Error occurs while deleting snapshot images from docker repository: {}', e.toString());
    tx.rollback();
} finally {
    tx.close();
}

"""cubicweb-ctl shell script to publish existing authority records."""


def publish_authority_records(cnx):
    for arecord in cnx.find('AuthorityRecord').entities():
        print('publishing', arecord)
        arecord.cw_adapt_to('IWorkflowable').fire_transition('publish')
    cnx.commit()


print('publishing authority record', cnx.find('AuthorityRecord'))
publish_authority_records(cnx)

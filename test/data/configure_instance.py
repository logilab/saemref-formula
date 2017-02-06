"""cubicweb-ctl shell script to configure a test instance."""


def setup(cnx):
    naa = cnx.create_entity('ArkNameAssigningAuthority', who=u'TEST', what=0)
    org = cnx.create_entity('Organization', name=u'Organisation de test', ark_naa=naa)
    user = cnx.create_entity('CWUser', login=u'user', upassword='user',
                             authority=org,
                             in_group=cnx.find('CWGroup', name=u'users').one())
    token = cnx.create_entity('AuthToken', enabled=True, id=u'token-user',
                              token_for_user=user)
    cnx.commit()

    print(token.token)


setup(cnx)

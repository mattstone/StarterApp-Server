config =
  appName: "startapp"
  port: 4000
  appEndPoint: "http://localhost"
  apiEndPoint: "http://localhost/api/rest"
  jwt_secret: "@#$%@$^^@#%$^#ASsd@#$%@$^^@#%$^#ASsd"
  session:
    secret: "Th#Hous#0fD$v!d!5$l!v3"
  permissionLevels:  # TODO: move to db
    USER: 1
    SUBSCRIBER: 2
    ADMIN: 2000
  mongodb:
    uri : "mongodb://localhost/starterapp"
  redis:
    host: "127.0.0.1"
    port: 6379
    db: 0
    ttl: 60 * 60 * 24 * 365 # 1 Year
  email:
    marketing : "contact@domain.com"
    support   : "support@domain.com"
    confirmationCodeTTL : 60 * 60 * 48 # Two days

module.exports = config

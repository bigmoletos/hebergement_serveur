import jenkins.model.*
import com.dabsquared.gitlabjenkins.connection.GitLabConnection
import com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig
import java.util.logging.Level
import java.util.logging.Logger

// =====================================================
// Script Groovy d'initialisation : connexion GitLab pour Jenkins
// - Configure la connexion GitLab pour l'intégration continue
// - Définit les timeouts, l'API token, et les logs de debug
// =====================================================
// Auteur : Bigmoletos
// Date : 15-04-2025
// =====================================================

// Configuration souhaitée
def gitlabConnectionName = "GitLab"
def gitlabUrl = "https://gitlab.com"
def gitlabApiTokenId = "gitlab-token" // Doit correspondre à l'ID du credential créé par CasC
def clientBuilderId = "autodetect"
def connectionTimeoutMillis = 10000
def readTimeoutMillis = 10000

// Accéder à l'instance Jenkins et à la configuration globale GitLab
Jenkins jenkins = Jenkins.get()
GitLabConnectionConfig gitlabConfig = jenkins.getDescriptorByType(GitLabConnectionConfig.class)

// Vérifier si une connexion avec le même nom existe déjà pour éviter les doublons
boolean connectionExists = gitlabConfig.getConnections().any { it.getName() == gitlabConnectionName }

if (!connectionExists) {
    println "--> [Groovy Init] Configuration de la connexion GitLab '${gitlabConnectionName}'..."

    // Créer une nouvelle instance de connexion GitLab
    // Note: Il faut fournir toutes les valeurs requises par le constructeur ou les setters.
    // Le constructeur simple semble nécessiter au moins le nom.
    // Les autres paramètres sont définis via les setters.
    GitLabConnection connection = new GitLabConnection(gitlabConnectionName)

    // Définir les propriétés de la connexion
    connection.setUrl(gitlabUrl)
    connection.setApiTokenId(gitlabApiTokenId)
    connection.setClientBuilderId(clientBuilderId)
    connection.setConnectionTimeout(connectionTimeoutMillis) // Définition directe des timeouts
    connection.setReadTimeout(readTimeoutMillis)         // Définition directe des timeouts
    connection.setIgnoreCertificateErrors(false)        // Valeur par défaut, mais explicitons

    // Ajouter la nouvelle connexion à la liste existante
    List<GitLabConnection> connections = new ArrayList<>(gitlabConfig.getConnections())
    connections.add(connection)
    gitlabConfig.setConnections(connections)

    // Sauvegarder la configuration globale de Jenkins
    gitlabConfig.save()
    jenkins.save()

    println "--> [Groovy Init] Connexion GitLab '${gitlabConnectionName}' configurée avec succès."
} else {
    println "--> [Groovy Init] La connexion GitLab '${gitlabConnectionName}' existe déjà. Aucune action requise."
}

return // Terminer le script

Logger.getLogger("hudson.plugins.git").setLevel(Level.FINER)
Logger.getLogger("org.jenkinsci.plugins.gitclient").setLevel(Level.FINER)
Logger.getLogger("org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition").setLevel(Level.FINER)
Logger.getLogger("com.cloudbees.plugins.credentials").setLevel(Level.FINER)
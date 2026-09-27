# Environnement commun aux scripts (sourcé, pas exécuté).
# Le projet cible Java 21 : sur macOS, on le sélectionne s'il n'est pas le JDK par défaut.
if [ -x /usr/libexec/java_home ] && java21=$(/usr/libexec/java_home -v 21 2>/dev/null); then
  export JAVA_HOME=$java21
fi

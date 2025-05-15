import socket
import requests
import time
import docker
import logging
from typing import Dict, Any

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


class ServiceDiagnostic:

    def __init__(self):
        self.docker_client = docker.from_env()

    def check_port_availability(self, port: int) -> bool:
        """Vérifie si un port est disponible"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.bind(('localhost', port))
            available = True
        except:
            available = False
        finally:
            sock.close()
        return available

    def get_container_status(self, container_name: str) -> Dict[str, Any]:
        """Obtient le statut détaillé d'un conteneur"""
        try:
            container = self.docker_client.containers.get(container_name)
            return {
                'status': container.status,
                'ports': container.ports,
                'network_settings': container.attrs['NetworkSettings'],
                'state': container.attrs['State']
            }
        except docker.errors.NotFound:
            return {'status': 'not_found'}

    def test_service_health(self,
                            url: str,
                            max_retries: int = 30,
                            delay: int = 2) -> bool:
        """Teste la santé d'un service avec retry"""
        logger.info(f"Testing health for {url}")
        for i in range(max_retries):
            try:
                response = requests.get(url)
                if response.status_code == 200:
                    logger.info(f"Service {url} is healthy")
                    return True
                logger.warning(
                    f"Attempt {i+1}: Service returned {response.status_code}")
            except requests.exceptions.ConnectionError:
                logger.warning(f"Attempt {i+1}: Connection failed")
            time.sleep(delay)
        logger.error(
            f"Service {url} is not healthy after {max_retries} attempts")
        return False

    def run_diagnostics(self):
        """Exécute tous les diagnostics"""
        # 1. Vérification des ports
        ports = [8092, 8093]
        for port in ports:
            available = self.check_port_availability(port)
            logger.info(f"Port {port} availability: {available}")

        # 2. Vérification des conteneurs
        containers = ['api_modelisation', 'api_ihm']
        for container in containers:
            status = self.get_container_status(container)
            logger.info(f"Container {container} status: {status}")

        # 3. Test de santé des services
        services = [
            'http://localhost:8092/health', 'http://localhost:8093/health'
        ]
        for service in services:
            healthy = self.test_service_health(service)
            logger.info(f"Service {service} health check: {healthy}")


if __name__ == "__main__":
    diagnostic = ServiceDiagnostic()
    diagnostic.run_diagnostics()

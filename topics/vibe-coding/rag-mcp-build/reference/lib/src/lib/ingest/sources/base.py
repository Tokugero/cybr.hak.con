from abc import ABC, abstractmethod
from collections.abc import Iterable

from ...models import Document


class SourceBase(ABC):
  @abstractmethod
  def documents(self) -> Iterable[Document]: ...

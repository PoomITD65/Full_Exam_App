from typing import Optional
from pydantic import BaseModel

class UpdatePersonReq(BaseModel):
    prefixNo: Optional[int] = None
    fName: Optional[str] = None
    lName: Optional[str] = None
    fNameEN: Optional[str] = None
    lNameEN: Optional[str] = None
    mobile: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    address_no: Optional[str] = None
    address_moo: Optional[str] = None
    address_road: Optional[str] = None
    address_soi: Optional[str] = None
    address_district: Optional[str] = None
    position: Optional[str] = None
    photo: Optional[str] = None
    status: Optional[int] = None

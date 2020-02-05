import React, {useEffect} from 'react';
import './Developers.css';
import {deleteApplication, getAppsInfo, getMyApps} from "../reducers/actions";
import {useStateValue} from "../reducers/state";
import Spinner from "../Elements/Spinner";
import {Link} from "react-router-dom";

function Developers() {
    const {state: {myApps}} = useStateValue();
    const {state: {appsInfo}} = useStateValue();

    useEffect(_ => {
        getMyApps().then(data => {
            const ids = data.map(item => item.returnValues.appId);
            getAppsInfo(ids).then();
        });
    }, []);

    //console.log(appsInfo);
    return <div className="Developers">
        <h1 className="text-center">Developers portal</h1>
        {appsInfo.errorMessage && <div className="alert alert-danger" role="alert">
            {appsInfo.errorMessage}
        </div>}
        <Link className="btn btn-primary mb-3" to="./developers-create">Create new app</Link>
        {myApps.inProcessReceiving && (!myApps.apps || myApps.apps.length === 0) && <Spinner/>}

        {myApps.apps && myApps.apps.length > 0 &&
        <table className="table table-bordered">
            <thead>
            <tr>
                <th scope="col">ID</th>
                <th scope="col">Title</th>
                <th scope="col">Description</th>
                <th scope="col">Actions</th>
            </tr>
            </thead>
            <tbody>

            {myApps.apps.map((item, i) => {
                const appId = item.returnValues.appId;
                const isLoaded = !!appsInfo[appId];
                const app = appsInfo[appId];
                return <tr key={i}>
                    <th scope="row">{appId}</th>
                    <td>{isLoaded ? app.title : '...'}</td>
                    <td>{isLoaded ? app.description : '...'}</td>
                    <td>
                        <Link to={`./developers-${appId}`} className="btn btn-info btn-sm mr-1">View</Link>

                        <button disabled={!isLoaded || !app.isActive} onClick={_ => {
                            if (window.confirm('Really delete?')) {
                                deleteApplication(appId).then(() => {
                                    alert(`App ${appId} deleted`);
                                });
                            }
                        }} className="btn btn-danger btn-sm">
                            Delete
                        </button>

                    </td>
                </tr>
            })}

            </tbody>
        </table>
        }
    </div>;
}

export default Developers;
